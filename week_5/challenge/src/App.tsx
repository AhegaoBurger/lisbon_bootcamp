import { ChakraProvider, Container, Box, Heading, VStack, Divider } from '@chakra-ui/react'
import { SuiClientProvider, WalletProvider, ConnectButton } from '@mysten/dapp-kit'
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Balances } from './components/Balances'
import { OwnedObjects } from './components/OwnedObjects'
import { MintNFT } from './components/MintNFT'

// Initialize the query client
const queryClient = new QueryClient()

// Configure the network
const networks = {
  devnet: new SuiClient({ url: getFullnodeUrl('devnet') }),
  mainnet: new SuiClient({ url: getFullnodeUrl('mainnet') }),
  testnet: new SuiClient({ url: getFullnodeUrl('testnet') }),
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider networks={networks} defaultNetwork="devnet">
        <WalletProvider>
          <ChakraProvider>
            <Container maxW="container.lg" py={10}>
              <VStack spacing={8} align="stretch">
                <Box textAlign="center">
                  <Heading mb={4}>Week 5 Sui Challenge</Heading>
                  <ConnectButton />
                </Box>
                
                <Divider />
                <Balances />
                
                <Divider />
                <MintNFT />
                
                <Divider />
                <OwnedObjects />
              </VStack>
            </Container>
          </ChakraProvider>
        </WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  )
}

export default App
