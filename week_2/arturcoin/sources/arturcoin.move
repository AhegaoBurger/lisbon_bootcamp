/// Module: arturcoin
module arturcoin::arturcoin;

use sui::coin::{Self, TreasuryCap, Coin};
use sui::url;
use sui::balance::{Self, Balance};
use sui::sui::SUI;

use std::ascii;

public struct ARTURCOIN has drop {}

const ARTURCOIN_PER_SUI: u64 = 10; // 1 SUI buys 10 ARTURCOIN

public struct CoinManager has key, store {
    id: UID,
    // Capability to mint ARTURCOIN
    treasury_cap: TreasuryCap<ARTURCOIN>,
    // Pool of SUI collected from swaps, used for burns
    sui_pool: Balance<SUI>
}

fun init(otw: ARTURCOIN, ctx: &mut TxContext) {
    let decimals: u8 = 9;
    let symbol: vector<u8> = b"ARTURCOIN";
    let name: vector<u8> = b"ARTURCOIN";
    let description: vector<u8> = b"This is a very valuable coin";
    let icon = url::new_unsafe(ascii::string(b"https://img.png"));
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
        sui_pool: balance::zero<SUI>() // Start with zero SUI
    };

    // transfer::public_transfer(treasury_cap, ctx.sender());
    // Freeze metadata
    transfer::public_freeze_object(metadata);
    // Share the manager object so others can interact with it
    transfer::public_share_object(manager);
}

public fun swap_sui_for_arturcoin(
    manager: &mut CoinManager, 
    sui_coin: Coin<SUI>,
    ctx: &mut TxContext
): Coin<ARTURCOIN> {
    // 1. Get the value of the incoming SUI coin
    let sui_value = sui_coin.value();

    // 2. Calculate the amount of ARTURCOIN to mint based on the rate
    let arturcoin_to_mint = sui_value * ARTURCOIN_PER_SUI;

    // 3. Mint the ARTURCOIN using the TreasuryCap stored in the manager
    let new_arturcoin = coin::mint(&mut manager.treasury_cap, arturcoin_to_mint, ctx);

    // 4. Take the user's SUI coin and add its balance to the manager's pool
    //    The sui_coin variable is consumed here.
    manager.sui_pool.join(sui_coin.into_balance());

    // 5. Return the newly minted ARTURCOIN to the caller
    new_arturcoin
}

public fun burn_arturcoin_for_sui(
    manager: &mut CoinManager,
    arturcoin_coin_to_burn: Coin<ARTURCOIN>,
    ctx: &mut TxContext
): Coin<SUI> {
    
}