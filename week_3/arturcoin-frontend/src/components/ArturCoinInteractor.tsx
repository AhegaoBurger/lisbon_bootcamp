// src/components/ArturCoinInteractor.tsx

import { useState, useEffect } from "react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction, // Already using the correct hook name
  useSuiClient,
} from "@mysten/dapp-kit";
// --- V1.0 Change: Import Transaction from the new path ---
import { Transaction } from "@mysten/sui/transactions";
import { toast } from "sonner";
import { packageId, coinManager } from "../constants";

// --- Configuration from environment variables ---
const PACKAGE_ID = packageId;
const COIN_MANAGER_ID = coinManager;
const NETWORK = import.meta.env.VITE_NETWORK || "devnet";
const MODULE_NAME = "arturcoin";
const ARTURCOIN_TYPE = `${PACKAGE_ID}::${MODULE_NAME}::ARTURCOIN`;
const SWAP_SUI_FUNCTION_NAME = "swap_sui_for_arturcoin";
const BURN_ARTURCOIN_FUNCTION_NAME = "burn_arturcoin_for_sui";
const ARTURCOIN_PER_SUI = 10;
const FEE_BASIS_POINTS = 100; // 1% fee (100 / 10000)

export function ArturCoinInteractor() {
  const currentAccount = useCurrentAccount();
  // --- V1.0 Change: Hook name is already correct, but the way it's called changes ---
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const suiClient = useSuiClient();

  // State for Swap
  const [suiAmountToSwap, setSuiAmountToSwap] = useState<string>("1");
  const [isSwapping, setIsSwapping] = useState(false);

  // State for Burn
  const [arturcoinAmountToBurn, setArturcoinAmountToBurn] =
    useState<string>("10");
  const [isBurning, setIsBurning] = useState(false);
  const [userArturCoinObjectId, setUserArturCoinObjectId] = useState<
    string | null
  >(null);

  // State for display and errors
  const [swapDigest, setSwapDigest] = useState<string | null>(null);
  const [burnDigest, setBurnDigest] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!currentAccount?.address) {
      setUserArturCoinObjectId(null);
      return;
    }

    const fetchArturCoin = async () => {
      try {
        const coins = await suiClient.getCoins({
          owner: currentAccount.address,
          coinType: ARTURCOIN_TYPE,
        });

        if (coins.data.length > 0) {
          // Use the largest coin object if multiple exist, or just the first one.
          // For simplicity, we take the first one here.
          // Consider merging coins if needed for larger burns.
          setUserArturCoinObjectId(coins.data[0].coinObjectId);
          console.log(
            "Found ARTURCOIN coin object:",
            coins.data[0].coinObjectId,
          );
        } else {
          console.log("No ARTURCOIN coin objects found for this address.");
          setUserArturCoinObjectId(null);
        }
      } catch (fetchError) {
        console.error("Error fetching ARTURCOIN coins:", fetchError);
        setUserArturCoinObjectId(null);
      }
    };

    fetchArturCoin();
    // Re-fetch when swap or burn completes successfully and digest changes
  }, [currentAccount?.address, suiClient, swapDigest, burnDigest]); // Added digests to dependencies

  const handleSwapSui = async () => {
    if (!currentAccount) {
      setErrorAndToast("Please connect your wallet first.");
      return;
    }
    const suiAmountNum = parseFloat(suiAmountToSwap);
    if (isNaN(suiAmountNum) || suiAmountNum <= 0) {
      setErrorAndToast("Please enter a valid positive SUI amount to swap.");
      return;
    }

    // Ensure it's a BigInt for calculations and pure function
    const suiAmountMist = BigInt(Math.floor(suiAmountNum * 1_000_000_000));

    setIsSwapping(true);
    setError(null);
    setSwapDigest(null);

    try {
      // --- V1.0 Change: Use Transaction class ---
      const txb = new Transaction();
      const [suiCoinForSwap] = txb.splitCoins(txb.gas, [
        // --- V1.0 Change: Use txb.pure.u64 for numeric values ---
        txb.pure.u64(suiAmountMist),
      ]);

      txb.moveCall({
        target: `${PACKAGE_ID}::${MODULE_NAME}::${SWAP_SUI_FUNCTION_NAME}`,
        arguments: [txb.object(COIN_MANAGER_ID), suiCoinForSwap],
      });

      txb.setGasBudget(100000000); // Consider adjusting based on typical gas usage

      // --- V1.0 Change: Pass the Transaction object directly, not serialized bytes ---
      const result = await signAndExecute({
        transaction: txb, // Pass the txb object
        // No need for options here as we only need the digest by default
      });

      console.log("Swap Transaction Successful:", result);
      const successMessage = `Swap successful! Digest: ${result.digest.substring(0, 10)}...`;
      toast.success(successMessage);
      setSwapDigest(result.digest);
      setIsSwapping(false);
      // Trigger re-fetch of coins by updating digest state (already handled by useEffect dependency)
    } catch (err) {
      handleTxError(err, "swap");
    }
  };

  const handleBurnArturcoin = async () => {
    if (!currentAccount) {
      setErrorAndToast("Please connect your wallet first.");
      return;
    }
    if (!userArturCoinObjectId) {
      setErrorAndToast(
        "Cannot perform burn: No ARTURCOIN coin object found in your wallet to split from. Swap SUI first or wait for indexer.",
      );
      return;
    }
    const arturcoinAmountNum = parseFloat(arturcoinAmountToBurn);
    if (isNaN(arturcoinAmountNum) || arturcoinAmountNum <= 0) {
      setErrorAndToast(
        "Please enter a valid positive ARTURCOIN amount to burn.",
      );
      return;
    }

    // Ensure it's a BigInt
    const arturcoinAmountSmallestUnit = BigInt(
      Math.floor(arturcoinAmountNum * 1_000_000_000),
    );

    setIsBurning(true);
    setError(null);
    setBurnDigest(null);

    try {
      // --- V1.0 Change: Use Transaction class ---
      const txb = new Transaction();

      // Check if the coin object ID is still valid before splitting
      // This is a good practice but adds an extra RPC call. Optional.
      // try {
      //   await suiClient.getObject({ id: userArturCoinObjectId });
      // } catch (getObjectError) {
      //   setErrorAndToast("ARTURCOIN object not found or invalid. It might have been spent. Refreshing coins...");
      //   setUserArturCoinObjectId(null); // Force re-fetch
      //   setIsBurning(false);
      //   return;
      // }

      const [arturCoinForBurn] = txb.splitCoins(
        txb.object(userArturCoinObjectId), // The specific coin object owned by the user
        [
          // --- V1.0 Change: Use txb.pure.u64 for numeric values ---
          txb.pure.u64(arturcoinAmountSmallestUnit),
        ],
      );

      txb.moveCall({
        target: `${PACKAGE_ID}::${MODULE_NAME}::${BURN_ARTURCOIN_FUNCTION_NAME}`,
        arguments: [
          txb.object(COIN_MANAGER_ID),
          arturCoinForBurn, // Pass the coin resulting from the split
        ],
      });

      txb.setGasBudget(100000000); // Consider adjusting

      // --- V1.0 Change: Pass the Transaction object directly ---
      const result = await signAndExecute({
        transaction: txb, // Pass the txb object
      });

      console.log("Burn Transaction Successful:", result);
      const successMessage = `Burn successful! Digest: ${result.digest.substring(0, 10)}...`;
      toast.success(successMessage);
      setBurnDigest(result.digest);
      setIsBurning(false);
      // Trigger re-fetch of coins by updating digest state (already handled by useEffect dependency)
      // Optimistically set to null, useEffect will confirm
      setUserArturCoinObjectId(null);
    } catch (err) {
      // Handle potential errors like insufficient balance in the specific coin object
      if (
        err instanceof Error &&
        err.message.includes("Insufficient balance")
      ) {
        setErrorAndToast(
          "Error: Insufficient balance in the selected ARTURCOIN object for the split.",
        );
        // Optionally try fetching again in case state is stale
        setUserArturCoinObjectId(null); // Force re-fetch
      } else {
        handleTxError(err, "burn");
      }
      setIsBurning(false); // Ensure loading state is reset on error
    }
  };

  const handleTxError = (err: unknown, type: "swap" | "burn") => {
    // Improved error message parsing
    let specificError = "An unknown error occurred.";
    if (err instanceof Error) {
      specificError = err.message;
      // Look for common Move abort explanations if available
      const match = err.message.match(/MoveAbort\((\w+)::(\w+), (\d+)\)/);
      if (match) {
        specificError = `Transaction failed in module ${match[1]}::${match[2]} with error code ${match[3]}.`;
        // You could map known error codes to user-friendly messages here
      } else if (err.message.includes("GasBalanceTooLow")) {
        specificError = "Insufficient SUI balance for gas fees.";
      }
    }
    console.error(`Error during ${type}:`, err); // Log the full error for debugging
    setError(`Error: ${specificError}`);
    toast.error(`Error: ${specificError}`);
    if (type === "swap") setIsSwapping(false);
    else setIsBurning(false);
  };

  const setErrorAndToast = (message: string) => {
    setError(message);
    toast.error(message);
  };

  // --- UI Remains the same ---
  return (
    <div
      style={{
        border: "1px solid #ccc",
        padding: "20px",
        margin: "20px 0",
        borderRadius: "8px",
        fontFamily: "sans-serif", // Added for better readability
      }}
    >
      <h2>Interact with {MODULE_NAME.toUpperCase()}</h2>
      <p style={{ wordBreak: "break-all" }}>
        {" "}
        {/* Ensure long IDs wrap */}
        <strong>Package ID:</strong> {PACKAGE_ID}
      </p>
      <p style={{ wordBreak: "break-all" }}>
        <strong>Coin Manager ID:</strong> {COIN_MANAGER_ID}
      </p>
      <p style={{ fontSize: "0.9em", color: "#555" }}>
        Rates: {ARTURCOIN_PER_SUI} ARTURCOIN per SUI | Fee:{" "}
        {FEE_BASIS_POINTS / 100}% ({FEE_BASIS_POINTS} basis points)
      </p>

      {!currentAccount && (
        <p style={{ color: "orange", fontWeight: "bold" }}>
          Connect your wallet to interact.
        </p>
      )}

      {error && (
        <p
          style={{
            color: "red",
            marginTop: "10px",
            fontWeight: "bold",
            wordBreak: "break-word",
          }}
        >
          {error}
        </p>
      )}

      {/* Swap Section */}
      <div
        style={{
          marginTop: "20px",
          padding: "15px",
          border: "1px dashed lightblue",
          borderRadius: "5px",
        }}
      >
        <h3>Swap SUI for {MODULE_NAME.toUpperCase()}</h3>
        <label htmlFor="suiAmount">SUI Amount:</label>
        <input
          type="number"
          id="suiAmount"
          value={suiAmountToSwap}
          onChange={(e) => setSuiAmountToSwap(e.target.value)}
          disabled={isSwapping || !currentAccount}
          style={{
            marginLeft: "10px",
            marginRight: "10px",
            width: "100px",
            padding: "5px",
          }}
          min="0.000000001"
          step="0.1"
        />
        <button
          onClick={handleSwapSui}
          disabled={isSwapping || !currentAccount}
          style={{
            padding: "6px 12px",
            cursor: isSwapping || !currentAccount ? "not-allowed" : "pointer",
          }}
        >
          {isSwapping ? "Swapping..." : `Swap SUI`}
        </button>
        {swapDigest && (
          <p
            style={{
              color: "green",
              marginTop: "10px",
              wordBreak: "break-all",
            }}
          >
            Success! Tx Digest:{" "}
            <a
              href={`https://suiscan.xyz/mainnet/tx/${swapDigest}`} // Using Suiscan as an alternative explorer link
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: "green" }}
            >
              {swapDigest}
            </a>
          </p>
        )}
      </div>

      {/* Burn Section */}
      <div
        style={{
          marginTop: "20px",
          padding: "15px",
          border: "1px dashed lightcoral",
          borderRadius: "5px",
        }}
      >
        <h3>Burn {MODULE_NAME.toUpperCase()} for SUI</h3>
        {!userArturCoinObjectId &&
          currentAccount &&
          !isBurning && ( // Show only if not burning
            <p style={{ color: "orange", fontSize: "0.9em" }}>
              Searching for an ARTURCOIN coin in your wallet... (If you just
              swapped, it might take a moment to appear)
            </p>
          )}
        <label htmlFor="arturcoinAmount">
          {MODULE_NAME.toUpperCase()} Amount:
        </label>
        <input
          type="number"
          id="arturcoinAmount"
          value={arturcoinAmountToBurn}
          onChange={(e) => setArturcoinAmountToBurn(e.target.value)}
          disabled={isBurning || !currentAccount || !userArturCoinObjectId}
          style={{
            marginLeft: "10px",
            marginRight: "10px",
            width: "100px",
            padding: "5px",
          }}
          min="0.000000001"
          step="1"
        />
        <button
          onClick={handleBurnArturcoin}
          disabled={isBurning || !currentAccount || !userArturCoinObjectId}
          style={{
            padding: "6px 12px",
            cursor:
              isBurning || !currentAccount || !userArturCoinObjectId
                ? "not-allowed"
                : "pointer",
          }}
        >
          {isBurning ? "Burning..." : `Burn ${MODULE_NAME.toUpperCase()}`}
        </button>
        {!userArturCoinObjectId &&
          currentAccount &&
          !isBurning && ( // Show only if not burning
            <p style={{ color: "red", fontSize: "0.9em", marginTop: "5px" }}>
              {error?.includes("ARTURCOIN object not found")
                ? error
                : "Cannot burn: No usable ARTURCOIN coin found in wallet."}
            </p>
          )}
        {burnDigest && (
          <p
            style={{
              color: "green",
              marginTop: "10px",
              wordBreak: "break-all",
            }}
          >
            Success! Tx Digest:{" "}
            <a
              href={`https://suiscan.xyz/mainnet/tx/${burnDigest}`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: "green" }}
            >
              {burnDigest}
            </a>
          </p>
        )}
      </div>
    </div>
  );
}
