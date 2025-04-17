module solution::silver;

use sui::url::{Self, Url};
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::sui::SUI;


// Error codes
const ECoinTooPoor: u64 = 0;


public struct SILVER has drop {}

public struct SilverVault has key, store {
    id: UID,
    sui: Balance<SUI>,
    fees: Balance<SUI>,
    rate: u64,
    fee_rate: u64,
    t_cap: TreasuryCap<SILVER>
}


fun init(otw: SILVER, ctx: &mut TxContext) {
    let (t_cap, c_metadata) = coin::create_currency(
        otw,
        9,
        b"AG",
        b"SILVER",
        b"True silver.", 
        // option::none<Url>(),
        option::some<Url>(url::new_unsafe_from_bytes(b"https://3.imimg.com/data3/RY/TG/MY-11434935/silver-metals-1000x1000.jpg")),
        ctx
    );

    let vault = SilverVault {
        id: object::new(ctx),
        sui: balance::zero<SUI>(),
        fees: balance::zero<SUI>(),
        rate: 150, // two decimals --> 1,5
        fee_rate: 100, // two decimals 
        t_cap
    };
    transfer::public_freeze_object(c_metadata);
    transfer::public_share_object(vault);
}


public fun swap(vault: &mut SilverVault, mut coin: Coin<SUI>, ctx: &mut TxContext): Coin<SILVER> {
    assert!(coin.value() > 100, ECoinTooPoor);
    let fee = coin.value() * vault.fee_rate / 10000;
    let fee_coin = coin.split(fee, ctx);
    vault.fees.join(fee_coin.into_balance());
    let amount_sui = coin.value();
    vault.sui.join(coin.into_balance());
    let amount_silver = amount_sui * vault.rate / 100;
    vault.t_cap.mint(amount_silver, ctx)
}


public fun burn(vault: &mut SilverVault, coin: Coin<SILVER>, ctx: &mut TxContext): Coin<SUI> {
    let amount = vault.t_cap.burn(coin);
    let return_amount = amount * 100 / vault.rate;
    let mut return_balance = vault.sui.split(return_amount);
    // taking the fee
    let fee_balance = return_balance.split(return_amount * vault.fee_rate / 10000);
    vault.fees.join(fee_balance);
    return_balance.into_coin(ctx)
}

// This is not required for the solution
public fun get_rate(vault: &SilverVault): u64 {
    vault.rate
}



#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let one_time_witness = SILVER {};
    init(one_time_witness, ctx);
}

#[test_only]
public fun get_fees(vault: &mut SilverVault): u64 {
    vault.fees.value()
}