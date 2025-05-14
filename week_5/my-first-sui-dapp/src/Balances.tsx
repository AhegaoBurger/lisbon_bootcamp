import { useCurrentAccount, useSuiClientQuery } from "@mysten/dapp-kit";
import { formatAddress } from "@mysten/sui/utils";
import { Flex } from "@radix-ui/themes";

export const Balances = () => {
  const account = useCurrentAccount();

  const { data, isLoading, isError } = useSuiClientQuery(
    "getAllBalances",
    {
      owner: account?.address || "",
    },
    {
      enabled: !!account,
    },
  );
  if (isLoading) {
    return <div>Loading...</div>;
  }
  if (isError) {
    return <div>Error fetching balances</div>;
  }

  if (!account) {
    return null;
  }

  return (
    <Flex direction="column" my="2" gapY="1">
      <div>Balances:</div>
      {data?.map(({ totalBalance, coinType }) => (
        <Flex key={coinType} gapX="2">
          <div>{formatAddress(coinType)}</div>
          <div>-</div>
          <div>{totalBalance}</div>
        </Flex>
      ))}
    </Flex>
  );
};
