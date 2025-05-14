# Lisbon Bootcamp <> Week 5

## Description

In this exercise, we are going to build a simple UI using ReactJS to:

- allow users connecting their Slush Wallet
- fetch and display the coin balances of the connected wallet ($SUI, $GOLD)
- fetch and display the NFTs owned by the connected wallet
- sign and execute a transaction to call the `buy` function and mint a `Dropout` NFT

## Technology Stack

We are going to build the UI using the following frameworks/libraries/tools:

- [@mysten/create-dapp](https://sdk.mystenlabs.com/dapp-kit/create-dapp) CLI tool to bootstrap our [ReactJS](https://react.dev/) app with [Vite](https://vite.dev/), using [Typescript](https://www.typescriptlang.org/)
- [Sui dApp Kit](https://sdk.mystenlabs.com/dapp-kit) to integrate our application with [Slush Wallet](https://slush.app/)
- [Tanstack Query](https://tanstack.com/query/latest) to handle the state/queries
- [Radix UI](https://www.radix-ui.com/) as a UI components library

## Steps

### 1. Bootstrapping the application

1.  Run the following command to bootstrap the appplication, choosing the `react-client-dapp` template:

```
npm create @mysten/dapp
```

This will create a new directory (with a default name `my-first-sui-dapp`), that will be the main directory of our work. 2. Run the following commands to install the required dependencies and start the dev server. You should be able to visit the app at http://localhost:5173/.

```
pnpm install
pnpm run dev
```

### 2. Prerequisites

1. Update the `defaultnetwork` of the `SuiClientProvider` in `main.tsx` to point to `devnet`
2. Let's delete the existing components (`<App />`, `<WalletStatus />`, `<OwnedObject />`) to showcase the whole integration from scratch

### 3. Wallet Connection

1. Use the `<ConnectButton />` as it is provided by the dappkit to connect a wallet
2. Use the `useCurrentAccount()` hook to get and display the connected account/address

### 3. Display the total token balances of the connected wallet

1. Create a new `<Balances />` component for displaying the balances ($SUI, $GOLD, etc)
2. Use the `getAllBalances` method to get the balances
3. Display a simple element for each token

### 4. Display the owned objects IDs of the connected wallet

1. Create a new `<OwnedObjects />` component for diplaying the owned objects
2. Use the `getOwnedObjects` method
3. Render just the object ID for each one
4. Try filtering by the `StructType`:
   - 0x2::coin::Coin<0x2::sui::SUI>
   - 0x09ffeb64b9d8aa52617a0448a6e3c2df00c51c5c099ba9fea58649b27e307d5a::collection::Dropout

### 5. Render the display properties of the owned Dropout NFTs

1. Add the `showDisplay: true` option to the `getOwnedObjects` method
2. Replace the object ID of each NFT with a card that shows:

   - The image
   - The name
   - A link to sui explorer

### 6. Mint a Dropout NFT

1. Add a `<MintNFTForm />` component that executes the transaction for minting a Dropout NFT:
2. Make a move call to the `0x09ffeb64b9d8aa52617a0448a6e3c2df00c51c5c099ba9fea58649b27e307d5a::collection::buy` function
3. Use the state shared object `0xcb066d9ed1ba7a5adea8bb1886cbf2a282feeab1ef4c744a78eb7c3bf600c2f9`
4. Use the `coinWithBalance` SDK method to build the payment coin:
   ```
   coinWithBalance({
      balance: 4_000_000_000,
      type: "0x497c5ec0e84067a5873b223f1494fddc3fdd64d39aa63ed786de9eb3cddfc09::gold::GOLD",
      useGasCoin: false,
    })(tx)
   ```
5. Sign the transaction with the method exposed by the `useSignTransaction()` hook
6. Execute the signed bytes with the `suiClient.executeTransactionBlock` method

### 7. [Optional if time allows] Add a text input for the arguments

1. Add an `<input />` for users to type the name of their NFT
2. Add an `<input />` for users to type the image url of their NFT

### 8. [Optional if time allows] Refetch the owned NFTs and the balances after minting

1. Add calling the `suiClient.waitForTransaction` method after
