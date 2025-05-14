import { ConnectButton } from "@mysten/dapp-kit";
import { Flex } from "@radix-ui/themes";
import { WalletStatus } from "./WalletStatus";
import { Balances } from "./Balances";
import { OwnedObjects } from "./OwnedObjects";
import { MintNFTForm } from "./MintNFTForm";

function App() {
  return (
    <Flex direction="column" gapY="5" p="5">
      <ConnectButton />
      <WalletStatus />
      <Balances />
      <OwnedObjects />
      <MintNFTForm />
    </Flex>
  );
}

export default App;
