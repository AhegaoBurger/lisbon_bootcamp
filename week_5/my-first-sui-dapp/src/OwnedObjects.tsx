import { useCurrentAccount, useSuiClientQuery } from "@mysten/dapp-kit";
import { formatAddress } from "@mysten/sui/utils";
import { Flex, Link, Text } from "@radix-ui/themes";

export function OwnedObjects() {
  const account = useCurrentAccount();
  const { data, isLoading, error } = useSuiClientQuery(
    "getOwnedObjects",
    {
      owner: account?.address as string,
      filter: {
        StructType:
          "0x09ffeb64b9d8aa52617a0448a6e3c2df00c51c5c099ba9fea58649b27e307d5a::collection::Dropout",
      },
      options: {
        showDisplay: true,
      },
    },
    {
      enabled: !!account,
    },
  );

  if (!account) {
    return null;
  }

  if (error) {
    return <Flex>Error fetching owned objects</Flex>;
  }

  if (isLoading) {
    return <Flex>Loading...</Flex>;
  }

  return (
    <Flex direction="row" my="2" gap="4" wrap="wrap">
      {!data?.data?.length && (
        <Flex>
          <Text>No objects of this type found</Text>
        </Flex>
      )}
      {data!.data.map((object) => {
        const display = object.data?.display?.data as {
          image_url: string;
          name: string;
        };
        return (
          <Flex
            key={object.data?.objectId}
            direction="column"
            align="center"
            p="2"
            style={{
              border: "1px solid #ccc",
              borderRadius: "8px",
              backgroundColor: "gray",
              width: "200px",
            }}
          >
            <img
              src={display.image_url}
              alt="NFT"
              style={{
                width: "auto",
                height: "auto",
              }}
            />
            <Text size="5" weight="medium">
              {display.name}
            </Text>
            <Link
              href={`https://devnet.suivision.xyz/object/${object.data!.objectId}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              {formatAddress(object.data!.objectId)}
            </Link>
          </Flex>
        );
      })}
    </Flex>
  );
}
