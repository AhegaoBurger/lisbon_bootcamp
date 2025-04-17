#!/bin/bash

# Enable local testing with --local flag
LOCAL_TEST=false
if [[ "$1" == "--local" ]]
then
    LOCAL_TEST=true
    shift # Remove --local from arguments
fi

# Default to devnet if no network specified
NETWORK=${1:-devnet}

# Function to check wallet setup
check_wallet() {
    # Check if sui is installed
    if ! command -v sui &> /dev/null
    then
        echo "Error: sui CLI is not installed"
        exit 1
    fi

    # Check if wallet is set up
    if ! sui client active-address &> /dev/null
    then
        echo "Error: No active wallet found. Please create or select a wallet with 'sui client'."
        exit 1
    fi

    # Get active address
    ACTIVE_ADDRESS=$(sui client active-address)
    echo "Using wallet address: $ACTIVE_ADDRESS"

    # Check wallet balance
    BALANCE=$(sui client gas --address "$ACTIVE_ADDRESS" | grep -oP "Balance: \K[0-9]+")
    if [[ -z "$BALANCE" || "$BALANCE" -lt 100000000000 ]]
    then
        echo "Error: Insufficient balance for deployment (need at least 0.1 SUI)"
        echo "Current balance: $BALANCE"
        exit 1
    fi
    echo "Wallet balance: $BALANCE MIST"
}

# Validate network unless in local test mode
if [[ "$LOCAL_TEST" == false ]]
then
    if [[ ! "$NETWORK" =~ ^(devnet|testnet|mainnet)$ ]]
    then
        echo "Error: Network must be devnet, testnet, or mainnet"
        exit 1
    fi
    check_wallet
fi

echo "Deploying to $NETWORK..."

# Navigate to Move project directory
cd "$(dirname "$0")/../arturcoin" || exit 1

# Build the contract
echo "Building contract..."
if [[ "$LOCAL_TEST" == true ]]
then
    echo "Local test mode: Skipping actual build"
    PACKAGE_ID="0x$(openssl rand -hex 32)"
    COIN_MANAGER_ID="0x$(openssl rand -hex 32)"
else
    sui move build || exit 1

    # Publish the contract and capture the output
    echo "Publishing contract..."
    PUBLISH_OUTPUT=$(sui client publish --gas-budget 100000000000) || exit 1

    # Extract Package ID using grep and awk
    PACKAGE_ID=$(echo "$PUBLISH_OUTPUT" | grep -A 1 "Published Objects:" | grep "Package ID:" | awk '{print $3}')

    # Extract Coin Manager ID - it's in the Created Objects section, usually the second or third object
    COIN_MANAGER_ID=$(echo "$PUBLISH_OUTPUT" | grep -A 4 "Created Objects:" | grep "ID:" | awk 'NR==3 {print $2}')

    # Log the full output for debugging
    echo "Full publish output:"
    echo "$PUBLISH_OUTPUT"
fi

if [ -z "$PACKAGE_ID" ] || [ -z "$COIN_MANAGER_ID" ]
then
    echo "Error: Failed to extract IDs from publish output"
    echo "Full publish output:"
    echo "$PUBLISH_OUTPUT"
    exit 1
fi

# Create deployments directory if it doesn't exist
DEPLOYMENTS_DIR="../deployments"
mkdir -p "$DEPLOYMENTS_DIR"

# Save to JSON file
cat > "$DEPLOYMENTS_DIR/$NETWORK.json" << EOF
{
  "packageId": "$PACKAGE_ID",
  "coinManagerId": "$COIN_MANAGER_ID",
  "network": "$NETWORK",
  "deploymentDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Update frontend .env file
cat > "../arturcoin-frontend/.env" << EOF
VITE_NETWORK=$NETWORK
VITE_PACKAGE_ID=$PACKAGE_ID
VITE_COIN_MANAGER_ID=$COIN_MANAGER_ID
EOF

if [[ "$LOCAL_TEST" == true ]]
then
    echo "Local test completed!"
    echo "Generated test IDs:"
else
    echo "Deployment successful!"
    echo "Network: $NETWORK"
fi

echo "Package ID: $PACKAGE_ID"
echo "Coin Manager ID: $COIN_MANAGER_ID"
echo
echo "Configuration files updated:"
echo "- deployments/$NETWORK.json"
echo "- arturcoin-frontend/.env"

# Print instructions for testing
if [[ "$LOCAL_TEST" == true ]]
then
    echo
    echo "Local test mode: Files were updated with randomly generated IDs"
    echo "To test the actual deployment, run without --local flag:"
    echo "./deploy.sh [network]"
fi