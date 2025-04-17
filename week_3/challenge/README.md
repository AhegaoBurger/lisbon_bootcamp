# Challenge 3

In this challenge make sure to import the sdk library and publish the contract from the previous workshop.
Save the IDs of the package and shared objects that are created by the contract in a file that exports them and start another file that will need to contain the following functions:

- Write a PTB that will mint an arbitrary amount of (GOLD or the name you gave) coins and send them to the caller. Also execute the transaction.

- In the same function from above, find the ID of the coin from the response, and create a new transaction that calls the stake function to stake the coin.

- Create a new function with a PTB that combines both of the above, first calls mint and then calls stake with the result of mint

- Use the `sui client faucet` command to get a coin with 10 SUI (if you don't have a SUI coin yet) and write a read call towards the chain that will return he ID of the first SUI coin it finds in an address.

- Write a function that splits a coin into 4 equal coins, save the IDs of the newly created coins from the response and find the total storage rebate value of these 4 coins added using the sdk (hard)

- Merge the 4 coins with the initial coin, read the amount of gas paid from the response, be ready to explain why you think the result was as such

- Make sure you have staked a large amount of GOLD (or whatever name you gave to your coin) in the staking pool. Get SUI coins for your address if you don't have from the faucet. The request is in the same PTB: 
   - Call the exchange_for_sui function where you give SUI to get GOLD coins
   - Unstake your GOLD previously staked GOLD coins
   - Determine and return from the response how much SUI you got as rewards from the response of the transaction execution
