module arturcoin::staking;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::dynamic_field as df;
use sui::sui::SUI;
use sui::table::{Self, Table};

use arturcoin::arturcoin::ARTURCOIN;

const PRICE_IN_SUI: u64 = 10_000_000_000;
const AMOUNT_OF_GOLD: u64 = 50_000_000_000;
// const ADMIN_ADDRESS: address = @0x38e6bd6c23b8cd9b8ea0e18bd45da43406190df850b1d47614fd573eac41a913;

// Errors 
const ERequestedValueTooHigh: u64 = 0;
const EWrongAmountOfSui: u64 = 1;
const EUserHasNoStake: u64 = 2;
const EAmountTooHigh: u64 = 3;
const ENotEnoughStakedGOLD: u64 = 4;

public struct AdminCap has key, store  {
    id: UID,
}

public struct StakingPool has key, store {
    id: UID,
    coins: Balance<ARTURCOIN>,
    rewards: Balance<SUI>,
    staked_amounts: Table<address, u64>,
}

fun init(ctx: &mut TxContext) {
    let pool = StakingPool {
        id: object::new(ctx),
        coins: balance::zero<ARTURCOIN>(),
        rewards: balance::zero<SUI>(),
        staked_amounts: table::new<address, u64>(ctx)

    };

    let admin_cap = AdminCap{
        id: object::new(ctx)
    };

    transfer::public_share_object(pool);
    transfer::public_transfer(admin_cap, ctx.sender());
}

public fun stake(pool: &mut StakingPool, coin: Coin<ARTURCOIN>, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let amount_staked = coin.value();
    pool.coins.join(coin.into_balance());

    if(pool.staked_amounts.contains<address, u64>(sender)) {
        *pool.staked_amounts.borrow_mut<address, u64>(sender) =
          *pool.staked_amounts.borrow<address, u64>(sender) + amount_staked;
    } else {
        pool.staked_amounts.add(sender, amount_staked);
    };

}


public fun unstake(pool: &mut StakingPool, value: u64, ctx: &mut TxContext): (Coin<ARTURCOIN>, Coin<SUI>) {
    let sender = ctx.sender();
    // check if the user has a stake
    assert!(pool.staked_amounts.contains(sender), EUserHasNoStake);
    // check if the amount to unstake is valid
    let staked_amount = *pool.staked_amounts.borrow<address, u64>(sender);
    assert!( staked_amount >= value, ERequestedValueTooHigh);

    if (staked_amount == value) {
        pool.staked_amounts.remove<address, u64>(sender);
    } else {
        *pool.staked_amounts.borrow_mut(sender) = staked_amount - value;
    };

    // calculate rewards
    let reward = pool.rewards.value() * value / pool.coins.value();

    let coin_balance = pool.coins.split(value);
    let sui_balance = pool.rewards.split(reward);
    let gold_coin = coin::from_balance(coin_balance, ctx);
    let sui_coin = sui_balance.into_coin(ctx);

    (gold_coin, sui_coin)
}

public fun exchange_for_sui(pool: &mut StakingPool, coin: Coin<SUI>, ctx: &mut TxContext): Coin<ARTURCOIN> {
    assert!(coin.value() == PRICE_IN_SUI, EWrongAmountOfSui);
    assert!(pool.coins.value() >= AMOUNT_OF_GOLD, ENotEnoughStakedGOLD);
    pool.rewards.join(coin.into_balance());

    let coin_balance = pool.coins.split(AMOUNT_OF_GOLD);
    coin_balance.into_coin(ctx)
}