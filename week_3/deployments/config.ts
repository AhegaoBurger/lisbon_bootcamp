// src/config.ts
import devnetDeployment from '../deployments/devnet.json';
import testnetDeployment from '../deployments/testnet.json';
import mainnetDeployment from '../deployments/mainnet.json';

const DEPLOYMENTS = {
  devnet: devnetDeployment,
  testnet: testnetDeployment,
  mainnet: mainnetDeployment,
} as const;

type Network = 'devnet' | 'testnet' | 'mainnet';

export const CONFIG = {
  NETWORK: (process.env.REACT_APP_NETWORK || 'devnet') as Network,
  PACKAGE_ID: process.env.REACT_APP_PACKAGE_ID || DEPLOYMENTS.devnet.packageId,
  COIN_MANAGER_ID: process.env.REACT_APP_COIN_MANAGER_ID || DEPLOYMENTS.devnet.coinManagerId,

  // Add other configuration values here
  ARTURCOIN_PER_SUI: 10,
  FEE_BASIS_POINTS: 100,
  MODULE_NAME: 'arturcoin'
};
