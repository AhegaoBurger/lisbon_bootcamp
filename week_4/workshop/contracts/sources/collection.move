module contracts::collection;

use std::string::String;

use contract::gold::GOLD;

use sui::coin::Coin;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::display;
use sui::package;
use sui::table::{Self, Table};


// Errors
const EWrongAmount: u64 = 0;
const ENoSuchAddress: u64 = 1;
const ETooLate: u64 = 2;


public struct COLLECTION has drop {}

public struct State has key {
    id: UID,
    whitelist: Table<address, bool>,
    pre_paid: Table<address, bool>,
    income: Balance<GOLD>,
    initial_price: u64,
    expiration: u64,
    normal_price: u64
    // nfts: Table<ID, Dropout>
}

public struct Dropout has key, store {
    id: UID,
    name: String, // Dropout#123
    rarity: String,
    minted_at: u64, // timestamp ms
    image_url: String,
    description: String
}

public struct AdminCap has key {
    id: UID,
    
}

fun init(otw: COLLECTION, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let keys: vector<String> = vector[
        b"name".to_string(),
        // std::string::utf8(b"description")
        b"image_url".to_string(),
        b"creator".to_string(),
        b"description".to_string()
    ];

    let values: vector<String> = vector [
        b"{name}".to_string(),
        b"{image_url}".to_string(),
        b"ME".to_string(),
        b"{description}".to_string()
    ];

    let mut disp = display::new_with_fields<Dropout>(
         &publisher,
         keys,
         values,
         ctx
    );

    disp.update_version();

    let cap = AdminCap {
        id: object::new(ctx)
    };

    let state = State {
        id: object::new(ctx),
        whitelist: table::new<address, bool>(ctx),
        pre_paid: table::new<address, bool>(ctx),
        income: balance::zero<GOLD>(),
        initial_price: 1_000_000_000,
        expiration: 0,
        normal_price: 4_000_000_000
    };

    // TODO: Create a State object
    let sender = ctx.sender();
    transfer::public_transfer(disp, sender);
    transfer::public_transfer(publisher, sender);
    transfer::transfer(cap, sender);
    transfer::share_object(state);
}


public fun admin_mint(
    _: &AdminCap,
    name: String,
    description: String,
    image_url: String,
    rarity: String,
    clock: &Clock, // 0x6
    ctx: &mut TxContext
): Dropout
{
    let now = clock.timestamp_ms();
    Dropout {
        id: object::new(ctx),
        name,
        description,
        image_url,
        rarity,
        minted_at: now
    }
}

public fun admin_airdrop(
    _: &AdminCap,
    state: &mut State,
    recipient: address,
    name: String,
    description: String,
    image_url: String,
    rarity: String,
    clock: &Clock, // 0x6
    ctx: &mut TxContext
)
{
    assert!(state.pre_paid.contains(recipient), ENoSuchAddress);
    let now = clock.timestamp_ms();
    let uid = object::new(ctx);
    let nft = Dropout {
        id: uid,
        name,
        description,
        image_url,
        rarity,
        minted_at: now
    };

    state.pre_paid.remove(recipient);
    transfer::public_transfer(nft, recipient);
    
}

public fun admin_add_whitelisted(state: &mut State, _: &AdminCap, mut users: vector<address>) {
    while(!users.is_empty()) {
        let user = users.pop_back();
        state.whitelist.add(user, true);
    };
}

public fun pre_pay(state: &mut State, coin: Coin<GOLD>, clock: &Clock, ctx: &TxContext) {
    assert!(coin.value() == state.initial_price, EWrongAmount);
    assert!(clock.timestamp_ms() > state.expiration, ETooLate);
    let user = ctx.sender();
    state.income.join(coin.into_balance());
    state.pre_paid.add(user, true);

}

// example of directly buying an NFT
// This example is vulnerable because any user can call it and they can input any name and any image_url
public fun buy(
    state: &mut State,
    name: String,
    image_url: String,
    coin: Coin<GOLD>,
    clock: &Clock,
    ctx: &mut TxContext
): Dropout {
    assert!(state.normal_price == coin.value(), EWrongAmount);
    state.income.join(coin.into_balance());
    let nft_id = object::new(ctx);
    let random = nft_id.to_address().to_u256();
    let mut rarity = b"common".to_string();
    if (random % 13 == 0) {
        rarity = b"rare".to_string()
    };
    if (random % 29 == 0) {
        rarity = b"epic".to_string()
    };
    if (random % 144 == 0) {
        rarity = b"legendary".to_string()
    };
    Dropout {
        id: nft_id,
        name,
        rarity,
        minted_at: clock.timestamp_ms(),
        image_url,
        description: b"A dropout minted on demand!".to_string()
    }
}





#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let one_time_w = COLLECTION {};
    init(one_time_w, ctx);
}
