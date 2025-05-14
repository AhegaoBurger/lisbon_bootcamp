import { useCurrentAccount } from "@mysten/dapp-kit";
import { Text } from "@radix-ui/themes";

export function WalletStatus() {
  const account = useCurrentAccount();

  if (account) {
    return <Text>Connected Address: {account.address}</Text>;
  }
  return <Text>Wallet not connected</Text>;
}
