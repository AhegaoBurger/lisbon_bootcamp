// src/components/ArturCoinInteractor.tsx

import { useState, useEffect } from "react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { toast } from "sonner";

// --- Configuration - Replace with your actual IDs ---
const PACKAGE_ID =
  "0x52498d7a3dd5eab73f4d39970dd567e12760d0adeefff4508f67fd4870f149a4";
const COIN_MANAGER_ID =
  "0xbda61c845a09e08a67fd23f7e4da5c6f6aadd01e71d1ff70a53eaf4c2a886e1a";
const MODULE_NAME = "arturcoin";
const ARTURCOIN_TYPE = `${PACKAGE_ID}::${MODULE_NAME}::ARTURCOIN`;
const SWAP_SUI_FUNCTION_NAME = "swap_sui_for_arturcoin";
const BURN_ARTURCOIN_FUNCTION_NAME = "burn_arturcoin_for_sui";
const ARTURCOIN_PER_SUI = 10;
const FEE_BASIS_POINTS = 100; // 1% fee (100 / 10000)

export function ArturCoinInteractor() {
  const currentAccount = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const suiClient = useSuiClient();

  // State for Swap
  const [suiAmountToSwap, setSuiAmountToSwap] = useState<string>("1");
  const [isSwapping, setIsSwapping] = useState(false);

  // State for Burn
  const [arturcoinAmountToBurn, setArturcoinAmountToBurn] = useState<string>("10");
  const [isBurning, setIsBurning] = useState(false);
  const [userArturCoinObjectId, setUserArturCoinObjectId] = useState<string | null>(null);

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
          setUserArturCoinObjectId(coins.data[0].coinObjectId);
          console.log("Found ARTURCOIN coin object:", coins.data[0].coinObjectId);
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
  }, [currentAccount?.address, suiClient]);

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

    const suiAmountMist = BigInt(Math.floor(suiAmountNum * 1_000_000_000));

    setIsSwapping(true);
    setError(null);
    setSwapDigest(null);

    try {
      const txb = new TransactionBlock();
      const [suiCoinForSwap] = txb.splitCoins(txb.gas, [txb.pure(suiAmountMist)]);

      txb.moveCall({
        target: `${PACKAGE_ID}::${MODULE_NAME}::${SWAP_SUI_FUNCTION_NAME}`,
        arguments: [
          txb.object(COIN_MANAGER_ID),
          suiCoinForSwap,
        ],
      });

      txb.setGasBudget(100000000);

      const result = await signAndExecute({
        transaction: txb.serialize(),
      });

      console.log("Swap Transaction Successful:", result);
      const successMessage = `Swap successful! Digest: ${result.digest.substring(0, 10)}...`;
      toast.success(successMessage);
      setSwapDigest(result.digest);
      setIsSwapping(false);
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
        "Cannot perform burn: No ARTURCOIN coin object found in your wallet to split from. Swap SUI first.",
      );
      return;
    }
    const arturcoinAmountNum = parseFloat(arturcoinAmountToBurn);
    if (isNaN(arturcoinAmountNum) || arturcoinAmountNum <= 0) {
      setErrorAndToast("Please enter a valid positive ARTURCOIN amount to burn.");
      return;
    }

    const arturcoinAmountSmallestUnit = BigInt(
      Math.floor(arturcoinAmountNum * 1_000_000_000),
    );

    setIsBurning(true);
    setError(null);
    setBurnDigest(null);

    try {
      const txb = new TransactionBlock();
      const [arturCoinForBurn] = txb.splitCoins(
        txb.object(userArturCoinObjectId),
        [txb.pure(arturcoinAmountSmallestUnit)],
      );

      txb.moveCall({
        target: `${PACKAGE_ID}::${MODULE_NAME}::${BURN_ARTURCOIN_FUNCTION_NAME}`,
        arguments: [
          txb.object(COIN_MANAGER_ID),
          arturCoinForBurn,
        ],
      });

      txb.setGasBudget(100000000);

      const result = await signAndExecute({
        transaction: txb.serialize(),
      });

      console.log("Burn Transaction Successful:", result);
      const successMessage = `Burn successful! Digest: ${result.digest.substring(0, 10)}...`;
      toast.success(successMessage);
      setBurnDigest(result.digest);
      setIsBurning(false);

      if (currentAccount?.address) {
        setUserArturCoinObjectId(null);
      }
    } catch (err) {
      handleTxError(err, "burn");
    }
  };

  const handleTxError = (err: unknown, type: "swap" | "burn") => {
    const errorMessage =
      err instanceof Error ? err.message : "An unknown error occurred building transaction";
    console.error(`Error during ${type}:`, err);
    setError(`Error: ${errorMessage}`);
    toast.error(`Error: ${errorMessage}`);
    if (type === "swap") setIsSwapping(false);
    else setIsBurning(false);
  };

  const setErrorAndToast = (message: string) => {
    setError(message);
    toast.error(message);
  };

  return (
    <div
      style={{
        border: "1px solid #ccc",
        padding: "20px",
        margin: "20px 0",
        borderRadius: "8px",
      }}
    >
      <h2>Interact with {MODULE_NAME.toUpperCase()}</h2>
      <p>
        <strong>Package ID:</strong> {PACKAGE_ID}
      </p>
      <p>
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
        <p style={{ color: "red", marginTop: "10px", fontWeight: "bold" }}>
          Error: {error}
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
        <label htmlFor="suiAmount">SUI Amount to Swap:</label>
        <input
          type="number"
          id="suiAmount"
          value={suiAmountToSwap}
          onChange={(e) => setSuiAmountToSwap(e.target.value)}
          disabled={isSwapping || !currentAccount}
          style={{ marginLeft: "10px", marginRight: "10px", width: "100px" }}
          min="0.000000001"
          step="0.1"
        />
        <button
          onClick={handleSwapSui}
          disabled={isSwapping || !currentAccount}
        >
          {isSwapping ? "Swapping..." : `Swap SUI`}
        </button>
        {swapDigest && (
          <p style={{ color: "green", marginTop: "10px" }}>
            Success! Tx Digest:{" "}
            <a
              href={`https://suiexplorer.com/txblock/${swapDigest}?network=devnet`}
              target="_blank"
              rel="noopener noreferrer"
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
        {!userArturCoinObjectId && currentAccount && (
          <p style={{ color: "orange", fontSize: "0.9em" }}>
            Searching for an ARTURCOIN coin in your wallet to use for burning...
          </p>
        )}
        <label htmlFor="arturcoinAmount">ARTURCOIN Amount to Burn:</label>
        <input
          type="number"
          id="arturcoinAmount"
          value={arturcoinAmountToBurn}
          onChange={(e) => setArturcoinAmountToBurn(e.target.value)}
          disabled={isBurning || !currentAccount || !userArturCoinObjectId}
          style={{ marginLeft: "10px", marginRight: "10px", width: "100px" }}
          min="0.000000001"
          step="1"
        />
        <button
          onClick={handleBurnArturcoin}
          disabled={isBurning || !currentAccount || !userArturCoinObjectId}
        >
          {isBurning ? "Burning..." : `Burn ${MODULE_NAME.toUpperCase()}`}
        </button>
        {!userArturCoinObjectId && currentAccount && (
          <p style={{ color: "red", fontSize: "0.9em" }}>
            Cannot burn: No ARTURCOIN found in wallet.
          </p>
        )}
        {burnDigest && (
          <p style={{ color: "green", marginTop: "10px" }}>
            Success! Tx Digest:{" "}
            <a
              href={`https://suiexplorer.com/txblock/${burnDigest}?network=devnet`}
              target="_blank"
              rel="noopener noreferrer"
            >
              {burnDigest}
            </a>
          </p>
        )}
      </div>
    </div>
  );
}