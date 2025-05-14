import {
  useCurrentAccount,
  useSignTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { coinWithBalance, Transaction } from "@mysten/sui/transactions";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import { Button, Flex } from "@radix-ui/themes";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

export const MintNFTForm = () => {
  const queryClient = useQueryClient();
  const account = useCurrentAccount();
  const { mutateAsync } = useSignTransaction();
  const suiClient = useSuiClient();
  const [name, setName] = useState("test");
  const [imageUrl, setImageUrl] = useState("https://i.imgur.com/yvNbUed.png");
  const [bytes, setBytes] = useState("");
  const [signature, setSignature] = useState("");

  const handleSignTransaction = async () => {
    if (!name || !imageUrl) {
      alert("Please fill in all fields");
      return;
    }
    if (!account) {
      alert("Please connect your wallet");
      return;
    }

    const tx = new Transaction();
    tx.setSender(account.address);

    const payment = coinWithBalance({
      balance: 4_000_000_000,
      type: "0x497c5ec0e84067a5873b223f1494fddc3fdd64d39aa63ed786de9eb3cddfc09::gold::GOLD",
      useGasCoin: false,
    })(tx);

    const nft = tx.moveCall({
      target:
        "0x09ffeb64b9d8aa52617a0448a6e3c2df00c51c5c099ba9fea58649b27e307d5a::collection::buy",
      arguments: [
        tx.object(
          "0xcb066d9ed1ba7a5adea8bb1886cbf2a282feeab1ef4c744a78eb7c3bf600c2f9",
        ),
        tx.pure.string(name),
        tx.pure.string(imageUrl),
        payment,
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    tx.transferObjects([nft], account!.address);

    const { bytes, signature } = await mutateAsync({
      transaction: tx,
    });

    setBytes(bytes);
    setSignature(signature);
  };

  const handleExecuteTransaction = async () => {
    await suiClient
      .executeTransactionBlock({
        transactionBlock: bytes,
        signature,
        options: {
          showEffects: true,
          showObjectChanges: true,
        },
      })
      .then(async (res) => {
        console.log("Transaction executed successfully", res.effects);
        if (res.effects?.status.status !== "success") {
          console.log("Failed to execute transaction");
          return;
        }
        setBytes("");
        setSignature("");
        await suiClient.waitForTransaction({ digest: res.digest });
        queryClient.invalidateQueries({
          queryKey: ["testnet", "getOwnedObjects"],
        });
      })
      .catch((err) => {
        console.error("Transaction execution failed", err);
      });
  };

  if (!account) {
    return null;
  }

  return (
    <Flex direction="column" my="2" gapY="3">
      <input
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="NFT Name..."
      />
      <input
        type="text"
        value={imageUrl}
        onChange={(e) => setImageUrl(e.target.value)}
        placeholder="NFT Image URL..."
      />
      <div>{bytes}</div>
      <Button onClick={handleSignTransaction}>Sign bytes</Button>
      {!!bytes && (
        <Button onClick={handleExecuteTransaction}>Execute bytes</Button>
      )}
    </Flex>
  );
};
