/// Module: arturcoin
module arturcoin::arturcoin;

use sui::coin::{Self, };
use sui::url;

use std::ascii;



public struct ARTURCOIN has drop {}

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

    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_freeze_object(metadata);
}


