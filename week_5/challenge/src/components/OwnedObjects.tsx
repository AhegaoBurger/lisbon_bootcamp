import { useCurrentAccount, useSuiClientQuery } from '@mysten/dapp-kit'
import { formatAddress } from '@mysten/sui/utils'
import { Box, SimpleGrid, Text, Image, Link, VStack, Spinner } from '@chakra-ui/react'
import { PACKAGE_ID, EXPLORER_URL } from '../constants'

export function OwnedObjects() {
  const account = useCurrentAccount()
  const { data, isLoading, error } = useSuiClientQuery(
    'getOwnedObjects',
    {
      owner: account?.address as string,
      filter: {
        StructType: `${PACKAGE_ID}::nft::Collection`,
      },
      options: {
        showDisplay: true,
      },
    },
    {
      enabled: !!account,
    }
  )

  if (!account) {
    return null
  }

  if (error) {
    return <Text color="red.500">Error fetching owned objects</Text>
  }

  if (isLoading) {
    return <Spinner />
  }

  return (
    <Box>
      <Text fontSize="xl" mb={4}>Your NFTs</Text>
      {!data?.data?.length ? (
        <Text>No NFTs found</Text>
      ) : (
        <SimpleGrid columns={{ base: 1, md: 2, lg: 3 }} spacing={6}>
          {data.data.map((object) => {
            const display = object.data?.display?.data as {
              image_url?: string
              name?: string
              description?: string
            }
            return (
              <VStack
                key={object.data?.objectId}
                p={4}
                bg="white"
                borderRadius="lg"
                boxShadow="md"
                spacing={3}
                align="stretch"
              >
                {display?.image_url && (
                  <Image
                    src={display.image_url}
                    alt={display.name || 'NFT'}
                    borderRadius="md"
                    objectFit="cover"
                    height="200px"
                    width="100%"
                  />
                )}
                <Text fontSize="lg" fontWeight="bold">
                  {display?.name || 'Unnamed NFT'}
                </Text>
                {display?.description && (
                  <Text fontSize="sm" color="gray.600">
                    {display.description}
                  </Text>
                )}
                <Link
                  href={`${EXPLORER_URL.DEVNET}/${object.data?.objectId}`}
                  isExternal
                  color="blue.500"
                  fontSize="sm"
                >
                  {formatAddress(object.data?.objectId || '')}
                </Link>
              </VStack>
            )
          })}
        </SimpleGrid>
      )}
    </Box>
  )
} 