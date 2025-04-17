import { Transaction } from "@mysten/sui/transactions";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromBase64 } from "@mysten/sui/utils";
import { packageId, vault} from "./constants";
import * as dotenv from "dotenv";
dotenv.config({path: "./.env"});

const privKeyBase64 = "AIVSfm/gdSJmyCAUEdCqww9ubQ1XQLd+y4n0xc4IeakG";
const privKey = Array.from(fromBase64(privKeyBase64));
privKey.shift();
const keypair = Ed25519Keypair.fromSecretKey(Uint8Array.from(privKey));


const client = new SuiClient({
    url: getFullnodeUrl('devnet')
})

const swap = async () => {
    const tx = new Transaction();

    const coin = tx.splitCoins(tx.gas, [tx.pure.u64(1_000_000_000)]);
    const silverCoin = tx.moveCall({
        target: `${packageId}::silver::swap`,
        arguments: [
            tx.object(vault),
            coin
        ]
    });

    tx.transferObjects([silverCoin], tx.pure.address(keypair.toSuiAddress()));

    const response = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: {
            showObjectChanges: true,
            showEffects: true
        }
    });
    console.log(response);
}

// swap()

const burn = async () => {
    const silveCoinId = "0x4816f8b57baf4ee09d568eb375ef34b3078cb1f3f61e2b944f2df44727a2cd8c";
    const tx = new Transaction();
    
    // use this if you want to force the transaction to execute on-chain
    // tx.setGasBudget(1_000_000_000);
    const suiCoin = tx.moveCall({
        target: `${packageId}::silver::burn`,
        arguments: [
            tx.object(vault),
            tx.object(silveCoinId)
        ]
    });

    tx.transferObjects([suiCoin], tx.pure.address(keypair.toSuiAddress()));

    // const builtTx = await tx.build({client: client});

    const response = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: {
            showEffects: true
        }
    });

    console.log(response);
}

// burn()

const devInspectExample = async () => {
    const tx = new Transaction();

    tx.moveCall({
        target: `${packageId}::silver::get_rate`,
        arguments: [
            tx.object(vault)
        ]
    });

    const response = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: '0x38e6bd6c23b8cd9b8ea0e18bd45da43406190df850b1d47614fd573eac41a913'
    });

    console.dir(response, {depth: 7});
}

// devInspectExample()