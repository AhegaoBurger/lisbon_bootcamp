// Contract IDs
export const PACKAGE_ID = '0xf31a7a905666ed61baf2c37230bc9b48c73d35a000c06a37c7b22417d5a1579d'
export const MINT_CAP_ID = '0xa432cb800fcfe968a940e928c02cca1f984d751db1e1ac8ba8ed72589b208fb5'
export const DISPLAY_ID = '0xd59d9bdc2cfadce2e05bc52953cab8cf3b0c59f4c43094618b508326a6f4041b'

// Contract module names
export const MODULES = {
  NFT: 'nft',
  AIRDROP: 'airdrop',
  ESCROW: 'escrow',
} as const

// Function names
export const FUNCTIONS = {
  MINT: 'mint',
  // Add other function names as needed
} as const

// Network configuration
export const NETWORK = {
  DEVNET: 'devnet',
  TESTNET: 'testnet',
  MAINNET: 'mainnet',
} as const

// Explorer URLs
export const EXPLORER_URL = {
  DEVNET: 'https://suiexplorer.com/object',
  TESTNET: 'https://suiexplorer.com/object',
  MAINNET: 'https://suiexplorer.com/object',
} as const 