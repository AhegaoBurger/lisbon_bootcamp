// src/main.tsx (or your app entry point)

import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import {
  SuiClientProvider,
  WalletProvider,
  createNetworkConfig,
} from "@mysten/dapp-kit";
import { getFullnodeUrl } from "@mysten/sui.js/client";
import "@mysten/dapp-kit/dist/index.css"; // Import default dapp-kit styles
import "./index.css"; // Your own global styles
import { Toaster } from "sonner";

// Configure connection to Sui Devnet
const { networkConfig } = createNetworkConfig({
  // You can add configurations for other networks here (e.g., testnet, mainnet)
  devnet: { url: getFullnodeUrl("devnet") },
  // testnet: { url: getFullnodeUrl('testnet') },
  // mainnet: { url: getFullnodeUrl('mainnet') },
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Toaster />
    <SuiClientProvider networks={networkConfig} defaultNetwork="devnet">
      <WalletProvider autoConnect={false}>
        {" "}
        {/* Set autoConnect={true} if desired */}
        <App />
      </WalletProvider>
    </SuiClientProvider>
  </React.StrictMode>,
);
