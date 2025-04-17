import { exec } from "child_process";
import { writeFileSync, mkdirSync, existsSync } from "fs";
import { resolve } from "path";
import util from "util";

const execAsync = util.promisify(exec);

interface DeploymentConfig {
  packageId: string;
  coinManagerId: string;
  network: string;
  deploymentDate: string;
}

async function main() {
  try {
    // Get network from command line argument or default to 'devnet'
    const network = process.argv[2] || "devnet";
    console.log(`Deploying to ${network}...`);

    // Build the contract
    console.log("Building contract...");
    const { stdout: buildOutput } = await execAsync("sui client build");
    console.log("Build output:", buildOutput);

    // Publish the contract
    console.log("Publishing contract...");
    const { stdout: publishOutput } = await execAsync(
      "sui client publish --gas-budget 100000000",
    );
    console.log("Publish output:", publishOutput);

    // Extract Package ID and Coin Manager ID from publish output
    const packageIdMatch = publishOutput.match(
      /Created Objects:.*\n.*ID: (0x[a-fA-F0-9]+)/,
    );
    const coinManagerMatch = publishOutput.match(
      /Created Objects:.*\n.*\n.*ID: (0x[a-fA-F0-9]+)/,
    );

    if (!packageIdMatch || !coinManagerMatch) {
      throw new Error("Failed to extract IDs from publish output");
    }

    const config: DeploymentConfig = {
      packageId: packageIdMatch[1],
      coinManagerId: coinManagerMatch[1],
      network,
      deploymentDate: new Date().toISOString(),
    };

    // Ensure deployments directory exists
    const deploymentsDir = resolve(__dirname, "../deployments");
    if (!existsSync(deploymentsDir)) {
      mkdirSync(deploymentsDir, { recursive: true });
    }

    // Save deployment config
    writeFileSync(
      resolve(deploymentsDir, `${network}.json`),
      JSON.stringify(config, null, 2),
    );

    // Update .env file
    const envContent =
      `
REACT_APP_NETWORK=${network}
REACT_APP_PACKAGE_ID=${config.packageId}
REACT_APP_COIN_MANAGER_ID=${config.coinManagerId}
    `.trim() + "\n";

    writeFileSync(resolve(__dirname, "../arturcoin-frontend/.env"), envContent);

    console.log(`\nDeployment successful!`);
    console.log(`Network: ${network}`);
    console.log(`Package ID: ${config.packageId}`);
    console.log(`Coin Manager ID: ${config.coinManagerId}`);
    console.log(`\nConfiguration files updated:`);
    console.log(`- deployments/${network}.json`);
    console.log(`- arturcoin-frontend/.env`);
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

main();
