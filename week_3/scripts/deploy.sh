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

# Function to check wallet setup and request tokens if needed
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

    # Calculate total balance across all coins
    echo "Checking wallet balance..."
    REQUIRED_BALANCE=100000000000

    get_total_balance() {
        local total=0
        # Capture both stdout and stderr but only process stdout for balance
        while read -r amount; do
            if [[ "$amount" =~ ^[0-9]+$ ]]; then
                total=$((total + amount))
            fi
        done < <(sui client gas "$ACTIVE_ADDRESS" 2>/dev/null | grep "MIST" | awk '{print $2}' | tr -d ',')
        echo "$total"
    }

    TOTAL_BALANCE=$(get_total_balance)
    echo "Current total balance: $TOTAL_BALANCE MIST ($(echo "scale=9; $TOTAL_BALANCE/1000000000" | bc) SUI)"
    
    if [[ "$TOTAL_BALANCE" -ge "$REQUIRED_BALANCE" ]]; then
        echo "Have enough SUI ($(echo "scale=9; $TOTAL_BALANCE/1000000000" | bc) SUI), proceeding with deployment..."
        return
    fi

    echo "Need at least $REQUIRED_BALANCE MIST (0.1 SUI), checking faucet..."

    # Request from faucet
    sui client faucet
    echo "Faucet request completed, waiting for transaction..."
    sleep 3
    
    # Recalculate total balance
    NEW_TOTAL=$(get_total_balance)
    
    if [[ "$NEW_TOTAL" -gt "$TOTAL_BALANCE" ]]; then
        local gained=$((NEW_TOTAL - TOTAL_BALANCE))
        local gained_sui=$(echo "scale=9; $gained/1000000000" | bc)
        echo "Successfully received $gained_sui SUI from faucet"
        TOTAL_BALANCE=$NEW_TOTAL
        
        if [[ "$TOTAL_BALANCE" -ge "$REQUIRED_BALANCE" ]]; then
            echo "Now have enough SUI for deployment"
        else
            echo "Warning: Still need more SUI. Have: $(echo "scale=9; $TOTAL_BALANCE/1000000000" | bc) SUI"
            echo "Need: $(echo "scale=9; $REQUIRED_BALANCE/1000000000" | bc) SUI"
            exit 1
        fi
    else
        echo "Error: Faucet request didn't increase balance"
        echo "Current total: $(echo "scale=9; $TOTAL_BALANCE/1000000000" | bc) SUI"
        echo "Make sure you're on devnet and try again"
        exit 1
    fi
    
    echo "Ready to deploy with $(echo "scale=9; $TOTAL_BALANCE/1000000000" | bc) SUI"
}

# Function to switch network
switch_network() {
    local target_network=$1
    echo "Switching to $target_network..."
    sui client switch --env $target_network
}

# Set up environment
if [[ "$LOCAL_TEST" == true ]]
then
    echo "Using local test environment..."
    check_wallet
else
    if [[ ! "$NETWORK" =~ ^(devnet|testnet|mainnet)$ ]]
    then
        echo "Error: Network must be devnet, testnet, or mainnet"
        exit 1
    fi
    
    # Switch to specified network and check wallet
    switch_network $NETWORK
    check_wallet
fi

echo "Deploying to ${LOCAL_TEST:+local}${LOCAL_TEST:-$NETWORK}..."

# Navigate to Move project directory
cd "$(dirname "$0")/../arturcoin" || exit 1

# Build the contract
echo "Building contract..."
sui move build || exit 1

# Publish the contract
echo "Publishing contract..."
COMMAND="sui client publish --gas-budget 100000000000"

if [[ "$LOCAL_TEST" == true ]]
then
    echo "Local test mode: Publishing to local network..."
else
    echo "Publishing to $NETWORK..."
fi

PUBLISH_OUTPUT=$(eval "$COMMAND") || exit 1

echo "Publish command output:"
echo "$PUBLISH_OUTPUT"

# Function to extract hex IDs
extract_id() {
    local output="$1"
    local pattern="$2"
    local n="$3"
    
    # Try different patterns
    local id
    id=$(echo "$output" | grep -A 2 "$pattern" | grep -o "0x[a-fA-F0-9]\{64\}" | sed -n "${n}p")
    if [[ -z "$id" ]]; then
        id=$(echo "$output" | grep -o "0x[a-fA-F0-9]\{64\}" | sed -n "${n}p")
    fi
    echo "$id"
}

# Extract IDs
echo "Extracting deployment IDs..."
PACKAGE_ID=$(extract_id "$PUBLISH_OUTPUT" "Published Objects" "1")
COIN_MANAGER_ID=$(extract_id "$PUBLISH_OUTPUT" "Created Objects" "2")

# Verify IDs
if [[ -z "$PACKAGE_ID" ]] || [[ -z "$COIN_MANAGER_ID" ]]
then
    echo "Error: Failed to extract IDs from publish output"
    echo "Raw publish output:"
    echo "$PUBLISH_OUTPUT"
    echo
    echo "Attempted to extract:"
    echo "Package ID: $PACKAGE_ID"
    echo "Coin Manager ID: $COIN_MANAGER_ID"
    exit 1
fi

echo "Successfully extracted IDs:"
echo "Package ID: $PACKAGE_ID"
echo "Coin Manager ID: $COIN_MANAGER_ID"

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