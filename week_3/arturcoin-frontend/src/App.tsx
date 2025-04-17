// src/App.tsx

import { ConnectButton } from "@mysten/dapp-kit";
import { ArturCoinInteractor } from "./components/ArturCoinInteractor";

function App() {
  return (
    <div style={{ padding: "20px" }}>
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "30px",
        }}
      >
        <h1>My ArturCoin dApp</h1>
        <ConnectButton connectText="Connect Sui Wallet" />
      </header>

      <main>
        <ArturCoinInteractor />
        {/* Add more components as needed */}
      </main>
    </div>
  );
}

export default App;
