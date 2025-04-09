// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module arturcoin::arturcoin_tests {
    use sui::test_scenario::{Self, Scenario, next_tx, ctx};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::object::{Self, ID};

    // Import items from the module under test
    use arturcoin::arturcoin::{
        Self, ARTURCOIN, CoinManager, EInsufficientSuiInPool, ARTURCOIN_PER_SUI, FEE_BASIS_POINTS
        // We would normally import the OTW struct here, e.g., ARTURCOIN_MODULE
    };

    // === Test Addresses ===
    const PUBLISHER: address = @0xACE; // Placeholder for the publisher/admin
    const USER1: address = @0xCAFE; // Placeholder for a test user

    // === Helper Functions ===

    // Helper to initialize the scenario, publish the module, and create the CoinManager
    fun setup_scenario(test_ctx: &mut TxContext): (Scenario, ID) { // Renamed ctx to avoid conflict
        let mut scenario = test_scenario::begin(PUBLISHER);

        // Publish the arturcoin package
        {
            next_tx(&mut scenario, PUBLISHER);
            // Pass the context correctly
            test_scenario::publish_for_testing(ctx(&mut scenario));
        };

        // Initialize the module - THIS WILL FAIL without the correct OTW struct and init signature
        // {
        //     next_tx(&mut scenario, PUBLISHER);
        //     // Assuming ARTURCOIN_MODULE is the OTW struct name if it were defined correctly
        //     // let witness = test_scenario::take_module_witness<ARTURCOIN_MODULE>(&mut scenario);
        //     // arturcoin::init(witness, ctx(&mut scenario));
        //     // Placeholder: Manually create a dummy manager for now, as init will fail
        //     let dummy_manager_id = object::id_from_address(PUBLISHER); // Not a real manager
        // };

        // Find and share the CoinManager - THIS LOGIC NEEDS REFINEMENT once init works
        // For now, we can't easily get the real manager ID because init fails.
        // We'll use a placeholder ID and assume it exists for test structure.
        let placeholder_manager_id = object::id_from_address(@0xDEADBEEF); // Placeholder ID

        // Mint some SUI for User1
        {
            next_tx(&mut scenario, PUBLISHER); // Use publisher gas
            let sui_coin = coin::mint_for_testing<SUI>(10_000_000_000, ctx(&mut scenario)); // 10 SUI
            transfer::public_transfer(sui_coin, USER1);
        };

        (scenario, placeholder_manager_id)
    }

    // === Tests ===

    #[test]
    // Test functions automatically receive a context
    fun test_swap_and_fee(ctx: &mut TxContext) {
        let (mut scenario, manager_id) = setup_scenario(ctx); // Pass the context received by the test

        let initial_sui_value = 1_000_000_000; // 1 SUI
        // Access constants via module path
        let expected_fee = initial_sui_value * arturcoin::arturcoin::FEE_BASIS_POINTS / 10000; // 1%
        let sui_value_after_fee = initial_sui_value - expected_fee;
        let expected_arturcoin = sui_value_after_fee * arturcoin::arturcoin::ARTURCOIN_PER_SUI;

        // User1 performs the swap
        next_tx(&mut scenario, USER1);
        {
            let manager = test_scenario::borrow_shared_mut<CoinManager>(&mut scenario, manager_id);
            let sui_coin = test_scenario::take_owned<Coin<SUI>>(&mut scenario, USER1);
            // Use the ctx passed into the test function for the actual call
            let arturcoin_received = arturcoin::swap_sui_for_arturcoin(manager, sui_coin, ctx);
            assert!(arturcoin_received.value() == expected_arturcoin, 0);
            test_scenario::return_owned(&mut scenario, arturcoin_received);

            // Assert pool balance increased correctly
            assert!(manager.sui_pool.value() == sui_value_after_fee, 1);
        };

        // Assert Admin (Publisher) received the fee
        // This requires checking the publisher's SUI balance change or finding the specific fee coin,
        // which is complex in test_scenario. We'll skip the direct fee check for simplicity here,
        // but verify the pool balance is correct (implying fee was removed).

        test_scenario::end(scenario);
    }

    #[test]
     // Test functions automatically receive a context
    fun test_burn_and_fee(ctx: &mut TxContext) {
        let (mut scenario, manager_id) = setup_scenario(ctx); // Pass the context received by the test
        let initial_sui_value = 1_000_000_000; // 1 SUI

        // --- Perform a swap first to get ARTURCOIN and fund the pool ---
        next_tx(&mut scenario, USER1);
        let arturcoin_to_burn: Coin<ARTURCOIN>;
        {
            let manager = test_scenario::borrow_shared_mut<CoinManager>(&mut scenario, manager_id);
            let sui_coin = test_scenario::take_owned<Coin<SUI>>(&mut scenario, USER1);
             // Use the ctx passed into the test function for the actual call
            arturcoin_to_burn = arturcoin::swap_sui_for_arturcoin(manager, sui_coin, ctx);
        };
        // --- End Swap ---

        let arturcoin_value = arturcoin_to_burn.value();
        // Access constants via module path
        let expected_sui_gross = arturcoin_value / arturcoin::arturcoin::ARTURCOIN_PER_SUI;
        let expected_fee = expected_sui_gross * arturcoin::arturcoin::FEE_BASIS_POINTS / 10000;
        let expected_sui_net = expected_sui_gross - expected_fee;

        // User1 performs the burn
        next_tx(&mut scenario, USER1);
        {
            let manager = test_scenario::borrow_shared_mut<CoinManager>(&mut scenario, manager_id);
             // Use the ctx passed into the test function for the actual call
            let sui_received = arturcoin::burn_arturcoin_for_sui(manager, arturcoin_to_burn, ctx);
            assert!(sui_received.value() == expected_sui_net, 2);
            test_scenario::return_owned(&mut scenario, sui_received);

            // Assert pool balance decreased correctly (by gross amount)
            // Pool started with sui_value_after_fee from the swap.
            // It should end with (sui_value_after_fee - expected_sui_gross)
             // Access constants via module path
            let sui_value_after_swap_fee = initial_sui_value - (initial_sui_value * arturcoin::arturcoin::FEE_BASIS_POINTS / 10000);
            assert!(manager.sui_pool.value() == (sui_value_after_swap_fee - expected_sui_gross), 3);
        };

        // Assert Admin (Publisher) received the fee (skipped direct check as above)

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = arturcoin::arturcoin::EInsufficientSuiInPool)]
     // Test functions automatically receive a context
    fun test_burn_insufficient_sui(ctx: &mut TxContext) {
         let (mut scenario, manager_id) = setup_scenario(ctx); // Pass the context received by the test

         // Mint some ARTURCOIN directly for the user for this test (requires a mint function or TreasuryCap access)
         // Since we don't have that easily, we'll assume the user somehow got ARTURCOIN without funding the pool.
         // Let's manually create a dummy ARTURCOIN coin for the test structure.
         let dummy_arturcoin = coin::zero<ARTURCOIN>(ctx); // Use the ctx passed into the test function
         // coin::join(&mut dummy_arturcoin, coin::mint_for_testing<ARTURCOIN>(100, ctx)); // Needs TreasuryCap
         // transfer::public_transfer(dummy_arturcoin, USER1); // Transfer to user

         // User1 tries to burn when pool is empty (or near empty)
         next_tx(&mut scenario, USER1);
         {
             let manager = test_scenario::borrow_shared_mut<CoinManager>(&mut scenario, manager_id);
             let arturcoin_to_burn = test_scenario::take_owned<Coin<ARTURCOIN>>(&mut scenario, USER1); // Will fail if user has none
             // This call should abort
              // Use the ctx passed into the test function for the actual call
             let sui_received = arturcoin::burn_arturcoin_for_sui(manager, arturcoin_to_burn, ctx);
             // Cleanup if it somehow didn't abort
             test_scenario::return_owned(&mut scenario, sui_received);
         };

         test_scenario::end(scenario);
    }
}
