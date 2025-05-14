import { useCurrentAccount, useSignTransaction, useSuiClient } from '@mysten/dapp-kit'
import { Transaction } from '@mysten/sui/transactions'
import { SUI_CLOCK_OBJECT_ID } from '@mysten/sui/utils'
import {
  Box,
  Button,
  FormControl,
  FormLabel,
  Input,
  VStack,
  useToast,
  Text,
} from '@chakra-ui/react'
import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'

export function MintNFT() {
  const queryClient = useQueryClient()
  const account = useCurrentAccount()
  const { mutateAsync: signTransaction } = useSignTransaction()
  const suiClient = useSuiClient()
  const toast = useToast()

  const [name, setName] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  const handleMint = async () => {
    if (!name || !imageUrl) {
      toast({
        title: 'Error',
        description: 'Please fill in all fields',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
      return
    }

    if (!account) {
      toast({
        title: 'Error',
        description: 'Please connect your wallet',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
      return
    }

    setIsLoading(true)

    try {
      const tx = new Transaction()
      tx.setSender(account.address)

      // Add your NFT minting move call here
      // This is just an example - you'll need to replace with your actual package and module
      const nft = tx.moveCall({
        target: '0x...::nft::mint', // Replace with your package ID and module
        arguments: [
          tx.pure.string(name),
          tx.pure.string(imageUrl),
          tx.object(SUI_CLOCK_OBJECT_ID),
        ],
      })

      tx.transferObjects([nft], account.address)

      const { bytes, signature } = await signTransaction({
        transaction: tx,
      })

      const result = await suiClient.executeTransactionBlock({
        transactionBlock: bytes,
        signature,
        options: {
          showEffects: true,
          showObjectChanges: true,
        },
      })

      if (result.effects?.status.status === 'success') {
        await suiClient.waitForTransaction({ digest: result.digest })
        queryClient.invalidateQueries({ queryKey: ['getOwnedObjects'] })
        
        toast({
          title: 'Success',
          description: 'NFT minted successfully!',
          status: 'success',
          duration: 5000,
          isClosable: true,
        })

        setName('')
        setImageUrl('')
      } else {
        throw new Error('Transaction failed')
      }
    } catch (error) {
      console.error('Minting failed:', error)
      toast({
        title: 'Error',
        description: 'Failed to mint NFT. Please try again.',
        status: 'error',
        duration: 5000,
        isClosable: true,
      })
    } finally {
      setIsLoading(false)
    }
  }

  if (!account) {
    return null
  }

  return (
    <Box>
      <Text fontSize="xl" mb={4}>Mint New NFT</Text>
      <VStack spacing={4} align="stretch">
        <FormControl>
          <FormLabel>NFT Name</FormLabel>
          <Input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter NFT name..."
          />
        </FormControl>

        <FormControl>
          <FormLabel>Image URL</FormLabel>
          <Input
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
            placeholder="Enter image URL..."
          />
        </FormControl>

        <Button
          colorScheme="blue"
          onClick={handleMint}
          isLoading={isLoading}
          loadingText="Minting..."
        >
          Mint NFT
        </Button>
      </VStack>
    </Box>
  )
} 