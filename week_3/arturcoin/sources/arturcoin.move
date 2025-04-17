/// Module: arturcoin
module arturcoin::arturcoin;

use sui::coin::{Self, TreasuryCap, Coin};
use sui::url;
use sui::balance::{Self, Balance};
use sui::sui::SUI;
// use sui::transfer; // Needed for transfer::public_transfer, freeze_object, share_object

use std::ascii;

public struct ARTURCOIN has drop {}

// Useful constants
const ARTURCOIN_PER_SUI: u64 = 10; // 1 SUI buys 10 ARTURCOIN
const FEE_BASIS_POINTS: u64 = 100;

// Errors
const EInsufficientSuiInPool: u64 = 1; // Error if the pool doesn't have enough SUI


public struct CoinManager has key, store {
    id: UID,
    // Capability to mint ARTURCOIN
    treasury_cap: TreasuryCap<ARTURCOIN>,
    // Pool of SUI collected from swaps, used for burns
    sui_pool: Balance<SUI>,
    // Address of the admin to send the fee to
    admin_address: address
}

fun init(otw: ARTURCOIN, ctx: &mut TxContext) {
    let decimals: u8 = 9;
    let symbol: vector<u8> = b"ARTURCOIN";
    let name: vector<u8> = b"ARTURCOIN";
    let description: vector<u8> = b"This is a very valuable coin, do you know why, cause it's ARTURCOIN";
    let icon = url::new_unsafe(ascii::string(b"https://avatars.githubusercontent.com/u/72599811?v=4"));
    let (treasury_cap, metadata) = coin::create_currency<ARTURCOIN>(
        otw,
        decimals,
        symbol,
        name,
        description,
        option::some(icon),
        ctx
    );

    // Create the manager object
    let manager = CoinManager {
        id: object::new(ctx),
        treasury_cap: treasury_cap, // Move the cap into the manager
        sui_pool: balance::zero<SUI>(), // Start with zero SUI
        admin_address: ctx.sender()
    };

    // Freeze metadata
    transfer::public_freeze_object(metadata);
    // Share the manager object so others can interact with it
    transfer::public_share_object(manager);
}

public fun swap_sui_for_arturcoin(
    manager: &mut CoinManager,
    sui_coin: Coin<SUI>,
    ctx: &mut TxContext
) {
    // 1. Get the value of the incoming SUI coin
    let sui_value = sui_coin.value();

    //
    let sui_fee = sui_value * FEE_BASIS_POINTS / 10000;

    //
    let sui_value_after_fee = sui_value - sui_fee;

    // 2. Calculate the amount of ARTURCOIN to mint based on the rate
    let arturcoin_to_mint = sui_value_after_fee * ARTURCOIN_PER_SUI;

    // 3. Mint the ARTURCOIN using the TreasuryCap stored in the manager
    let new_arturcoin = coin::mint(&mut manager.treasury_cap, arturcoin_to_mint, ctx);

    // 4. Handle the incoming SUI: split fee, transfer fee, add remainder to pool
    let mut sui_balance = sui_coin.into_balance(); // Make balance mutable to split from it
    let fee_balance = sui_balance.split(sui_fee); // Split fee amount off
    let fee_coin = coin::from_balance(fee_balance, ctx); // Create coin for the fee
    transfer::public_transfer(fee_coin, manager.admin_address); // Transfer fee to admin

    // Join the remaining balance (holding sui_value_after_fee) to the pool
    manager.sui_pool.join(sui_balance);

    // Instead of returning, transfer the coin to the sender
    transfer::public_transfer(new_arturcoin, ctx.sender());
}

public fun burn_arturcoin_for_sui(
    manager: &mut CoinManager,
    arturcoin_to_burn: Coin<ARTURCOIN>,
    ctx: &mut TxContext
) {
    // 1. Get the value of the incoming ARTURCOIN
    let arturcoin_value = arturcoin_to_burn.value();

    // 2. Calculate the amount of SUI the user should receive
    //    Inverse of the swap rate: SUI = ARTURCOIN / RATE
    //    Ensure integer division doesn't lose precision unfairly.
    //    If 1 SUI = 10 ARTURCOIN, then 1 ARTURCOIN = 0.1 SUI.
    //    Calculation: sui_to_return = arturcoin_value / ARTURCOIN_PER_SUI
    //    Make sure this aligns with your decimal strategy. If both have 9 decimals,
    //    burning 10 * 1_000_000_000 ARTURCOIN should yield 1 * 1_000_000_000 SUI (MIST).
    let sui_to_return = arturcoin_value / ARTURCOIN_PER_SUI;

    // 3. Check if the pool has enough SUI
    assert!(manager.sui_pool.value() >= sui_to_return, EInsufficientSuiInPool);

    // 4. Burn the user's ARTURCOIN using the TreasuryCap
    //    This consumes the arturcoin_to_burn variable.
    coin::burn(&mut manager.treasury_cap, arturcoin_to_burn);

    // Calculate the fee based on the gross amount
    let sui_fee = sui_to_return * FEE_BASIS_POINTS / 10000;

    // 5. Split the *gross* required SUI from the manager's pool
    let gross_sui_balance = manager.sui_pool.split(sui_to_return);

    // 6. Convert the gross Balance<SUI> into a Coin<SUI>
    let mut gross_sui_coin = coin::from_balance(gross_sui_balance, ctx); // Make coin mutable

    // 7. Split the fee amount from the gross coin
    let fee_coin = gross_sui_coin.split(sui_fee, ctx); // Use coin::split which takes Coin

    // 8. Transfer the fee coin to the admin
    transfer::public_transfer(fee_coin, manager.admin_address);

    // 9. Return the remaining SUI coin (holding the net amount) to the caller
    transfer::public_transfer(gross_sui_coin, ctx.sender());
}
