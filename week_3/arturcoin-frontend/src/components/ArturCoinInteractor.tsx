// src/components/ArturCoinInteractor.tsx

import { useState } from "react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { toast } from "sonner";

// Configuration
const PACKAGE_ID = "0xe13ba3c4eb89797c79aa7ef705007234720cce64e4ea5179332055699b1ef3b7";
const COIN_MANAGER_ID = "0x49c2d62eb95c3a17dd2b10ce8f57ca011571cee65ed1636204ec5048186be8f0";
const MODULE_NAME = "arturcoin";
const MINT_FUNCTION_NAME = "mint";
const DEVNET_EXPLORER_URL = "https://suiexplorer.com/txblock";

interface TransactionState {
  isLoading: boolean;
  error: string | null;
  digest: string | null;
}

export function ArturCoinInteractor() {
  const currentAccount = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const [mintAmount, setMintAmount] = useState<string>("1000");
  const [txState, setTxState] = useState<TransactionState>({
    isLoading: false,
    error: null,
    digest: null,
  });

  const resetTxState = () => {
    setTxState({
      isLoading: false,
      error: null,
      digest: null,
    });
  };

  const validateMintAmount = (amount: string): boolean => {
    const numAmount = Number(amount);
    return !isNaN(numAmount) && numAmount > 0;
  };

  const handleMint = async () => {
    if (!currentAccount) {
      const errorMsg = "Please connect your wallet first.";
      setTxState(prev => ({ ...prev, error: errorMsg }));
      toast.error(errorMsg);
      return;
    }

    if (!validateMintAmount(mintAmount)) {
      const errorMsg = "Please enter a valid positive amount to mint.";
      setTxState(prev => ({ ...prev, error: errorMsg }));
      toast.error(errorMsg);
      return;
    }

    resetTxState();
    setTxState(prev => ({ ...prev, isLoading: true }));

    try {
      const txb = new TransactionBlock();

      txb.moveCall({
        target: `${PACKAGE_ID}::${MODULE_NAME}::${MINT_FUNCTION_NAME}`,
        arguments: [
          txb.object(COIN_MANAGER_ID),
          txb.pure(mintAmount),
          txb.pure(currentAccount.address),
        ],
      });

      txb.setGasBudget(100000000);

      const result = await signAndExecute({
          transaction: txb.serialize(),
      });
      
      console.log("Mint Transaction Successful:", result);
      setTxState(prev => ({
        ...prev,
        isLoading: false,
        digest: result.digest,
      }));
      toast.success(`Successfully minted ${mintAmount} ${MODULE_NAME.toUpperCase()}`);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "An unknown error occurred";
      console.error("Error building transaction block:", err);
      setTxState(prev => ({
        ...prev,
        isLoading: false,
        error: `Error: ${errorMessage}`,
      }));
      toast.error(errorMessage);
    }
  };

  const containerStyle: React.CSSProperties = {
    border: "1px solid #ccc",
    padding: "2rem",
    margin: "2rem 0",
    borderRadius: "8px",
    maxWidth: "800px",
  };

  const inputGroupStyle: React.CSSProperties = {
    display: "flex",
    gap: "1rem",
    alignItems: "center",
    marginBottom: "1rem",
  };

  const buttonStyle: React.CSSProperties = {
    padding: "0.5rem 1rem",
    backgroundColor: txState.isLoading ? "#ccc" : "#0070f3",
    color: "white",
    border: "none",
    borderRadius: "4px",
    cursor: txState.isLoading ? "not-allowed" : "pointer",
  };

  const inputStyle: React.CSSProperties = {
    padding: "0.5rem",
    borderRadius: "4px",
    border: "1px solid #ccc",
  };

  return (
    <div style={containerStyle}>
      <h2>Interact with ArturCoin ({MODULE_NAME})</h2>
      
      <div style={{ marginBottom: "1.5rem" }}>
        <p><strong>Package ID:</strong> {PACKAGE_ID}</p>
        <p><strong>Coin Manager ID:</strong> {COIN_MANAGER_ID}</p>
      </div>

      {currentAccount ? (
        <div>
          <h3>Mint {MODULE_NAME.toUpperCase()}</h3>
          <div style={inputGroupStyle}>
            <label htmlFor="mintAmount">Amount to Mint:</label>
            <input
              type="number"
              id="mintAmount"
              value={mintAmount}
              onChange={(e) => setMintAmount(e.target.value)}
              disabled={txState.isLoading}
              style={inputStyle}
              min="1"
              step="1"
            />
            <button
              onClick={handleMint}
              disabled={txState.isLoading || !currentAccount}
              style={buttonStyle}
              aria-label={txState.isLoading ? "Minting in progress" : `Mint ${MODULE_NAME.toUpperCase()}`}
            >
              {txState.isLoading ? "Minting..." : `Mint ${MODULE_NAME.toUpperCase()}`}
            </button>
          </div>

          {txState.error && (
            <p style={{ color: "red", marginTop: "1rem" }}>
              {txState.error}
            </p>
          )}

          {txState.digest && (
            <p style={{ color: "green", marginTop: "1rem" }}>
              Success! Tx Digest:{" "}
              <a
                href={`${DEVNET_EXPLORER_URL}/${txState.digest}?network=devnet`}
                target="_blank"
                rel="noopener noreferrer"
                style={{ color: "#0070f3" }}
              >
                {txState.digest}
              </a>
            </p>
          )}
        </div>
      ) : (
        <p style={{ color: "orange", fontWeight: "bold" }}>
          Connect your wallet to interact with ArturCoin.
        </p>
      )}
    </div>
  );
}