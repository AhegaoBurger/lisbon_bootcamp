import { useState, useEffect } from "react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { Transaction } from '@mysten/sui/transactions';

// --- Configuration from environment variables ---
const PACKAGE_ID = import.meta.env.VITE_PACKAGE_ID;
const COIN_MANAGER_ID = import.meta.env.VITE_COIN_MANAGER_ID;
const NETWORK = import.meta.env.VITE_NETWORK || 'devnet';
const MODULE_NAME = "arturcoin";
const ARTURCOIN_TYPE = `${PACKAGE_ID}::${MODULE_NAME}::ARTURCOIN`;
const SWAP_SUI_FUNCTION_NAME = "swap_sui_for_arturcoin";
const BURN_ARTURCOIN_FUNCTION_NAME = "burn_arturcoin_for_sui";
const ARTURCOIN_PER_SUI = 10;
const FEE_BASIS_POINTS = 100; // 1% fee (100 / 10000)

const currentAccount = useCurrentAccount();
const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
const suiClient = useSuiClient();

// State for display and errors
const [swapDigest, setSwapDigest] = useState<string | null>(null);
const [burnDigest, setBurnDigest] = useState<string | null>(null);
const [error, setError] = useState<string | null>(null);