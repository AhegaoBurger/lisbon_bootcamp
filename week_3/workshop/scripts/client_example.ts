import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";



const client = new SuiClient({
    url: getFullnodeUrl("devnet")
});

const address = "0x38e6bd6c23b8cd9b8ea0e18bd45da43406190df850b1d47614fd573eac41a913";


const readAddressContents = async (address: string) => {
    const response = await client.getOwnedObjects({
        owner: address,
        options: {
            // showBcs: true,
            // showDisplay: true,
            showContent: true,
            // showOwner: true,
            // showPreviousTransaction: true,
            // showStorageRebate: true,
            showType: true,
        },
        filter: {
            StructType: `0x2::coin::Coin<0x2::sui::SUI>`
        }
    });
    console.dir(response, {depth: 5});``
}

// readAddressContents(address);


const getObjectDetails = async (objectId: string) => {
    const response = await client.getObject({
        id: objectId,
        options: {
            showType: true,
            showOwner: true
        }
    });

    console.dir(response, {depth: 7});
}

// getObjectDetails("0x87a0197ab8c0493ba515b49f10b8904aa259fb6114161e6f8403a51024cc0fe9");

const getTransaction = async (txDigest: string) => {
    const response = await client.getTransactionBlock({
        digest: txDigest,
        options: {
            showEffects: true,
            showInput: true,
            showObjectChanges: true,
            showBalanceChanges: true,
        }
    });

    // client.multiGetTransactionBlocks <-- to get more transactions in one call
    console.dir(response, {depth: 7});
}

// getTransaction("4KYFsPsbyY3gF1c7Z1qVV8v2kGPTGXLQZEFLGb23Dk9Q");


const getCheckpoint = async (sequenceNum: string) => {
    const resp = await client.getLatestCheckpointSequenceNumber();
    // console.log(resp);
    const response = await client.getCheckpoint({
        id: sequenceNum
    });

    console.dir(response, {depth: 7});
}

// getCheckpoint('816840'); 


const readPastObject = async (objectId: string, version: number) => {
    const response = await client.tryGetPastObject({
        id: objectId,
        version,
        options: {
            showOwner: true
        }
    });
    console.dir(response, {depth: 7});
}

// readPastObject("0x87a0197ab8c0493ba515b49f10b8904aa259fb6114161e6f8403a51024cc0fe9", 21);