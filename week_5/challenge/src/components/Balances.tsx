import { useCurrentAccount, useSuiClientQuery } from '@mysten/dapp-kit'
import { formatAddress } from '@mysten/sui/utils'
import { Box, VStack, Text, Flex, Spinner } from '@chakra-ui/react'

export function Balances() {
  const account = useCurrentAccount()

  const { data, isLoading, isError } = useSuiClientQuery(
    'getAllBalances',
    {
      owner: account?.address || '',
    },
    {
      enabled: !!account,
    }
  )

  if (!account) {
    return null
  }

  if (isLoading) {
    return <Spinner />
  }

  if (isError) {
    return <Text color="red.500">Error fetching balances</Text>
  }

  return (
    <Box>
      <Text fontSize="xl" mb={4}>Your Balances</Text>
      <VStack align="stretch" spacing={2}>
        {data?.map(({ totalBalance, coinType }) => (
          <Flex key={coinType} justify="space-between" p={2} bg="gray.50" borderRadius="md">
            <Text>{formatAddress(coinType)}</Text>
            <Text fontWeight="bold">{totalBalance}</Text>
          </Flex>
        ))}
      </VStack>
    </Box>
  )
} 