
#[test_only]
module solution::tests;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario as ts;

use solution::silver::{Self, SilverVault, SILVER};

const ADMIN: address = @0x111;
const USER: address = @0x222;

#[test]
public fun swap_test() {
    let mut scenario = ts::begin(ADMIN);
    {
        silver::init_for_testing(scenario.ctx());

    };

    scenario.next_tx(USER);
    {
        let mut vault = scenario.take_shared<SilverVault>();
        let user_coin = coin::mint_for_testing<SUI>(100_000_000_000, scenario.ctx());
        let silver_coin = silver::swap(&mut vault, user_coin, scenario.ctx());

        assert!(silver_coin.value() == 148_500_000_000);

        transfer::public_transfer(silver_coin, USER);
        ts::return_shared(vault);
    };

    scenario.next_tx(USER);
    {
        let mut vault = scenario.take_shared<SilverVault>();
        assert!(&vault.get_fees() == 1_000_000_000);
        ts::return_shared(vault);
    };

    scenario.next_tx(USER);
    {
        let silver_coin = scenario.take_from_sender<Coin<SILVER>>();
        let mut vault = scenario.take_shared<SilverVault>();

        let sui_coin  = vault.burn(silver_coin, scenario.ctx());

        assert!(sui_coin.value() == 98010000000);

        transfer::public_transfer(sui_coin, USER);

        ts::return_shared(vault);
    };


    scenario.end();
}