module contracts::collection;

use std::string::String;

use contract::gold::GOLD;

use sui::coin::Coin;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::display;
use sui::package;
use sui::table::Table;



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

    // TODO: Create a State object
    let sender = ctx.sender();
    transfer::public_transfer(disp, sender);
    transfer::public_transfer(publisher, sender);
    transfer::transfer(cap, sender);
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
    let id = uid.to_inner();
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





#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let one_time_w = COLLECTION {};
    init(one_time_w, ctx);
}





