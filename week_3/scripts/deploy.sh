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
    # We need 0.1 SUI = 100000000 MIST
    REQUIRED_BALANCE=100000000

    get_balance_in_mist() {
        local output
        # Run the command - consider removing 2>/dev/null during debugging if needed
        output=$(sui client gas "$ACTIVE_ADDRESS" 2>/dev/null)
        if [[ -z "$output" ]]; then
            echo "0" # No output probably means no gas coins
            return
        fi

        # Use awk to parse the table:
        # -F'│' sets the field separator to the vertical bar '│'
        # /^│ 0x/ filters for lines starting with '│ 0x' (these are the data lines)
        # {gsub(/ /,"",$3); total+=$3} removes spaces from the 3rd field (MIST balance column)
        #                               and adds its numeric value to the 'total' variable.
        # END {print total+0} prints the final total. '+0' ensures '0' is printed if no lines match.
        local total
        total=$(echo "$output" | awk -F'│' '/^│ 0x/ {gsub(/[[:space:]]/,"",$3); total+=$3} END {print total+0}')

        # Fallback in case awk produced no output or failed
        echo "${total:-0}"
    }

    format_sui_amount() {
        local mist=$1
        if [[ $mist -le 0 ]]; then
            echo "0.00"
            return
        fi
        printf "%.2f" "$(echo "scale=2; $mist/1000000000" | bc)"
    }

    TOTAL_BALANCE=$(get_balance_in_mist)
    TOTAL_BALANCE=${TOTAL_BALANCE:-0}
    TOTAL_SUI=$(format_sui_amount "$TOTAL_BALANCE")

    echo "Current balance: $TOTAL_SUI SUI"

    if [[ "$TOTAL_BALANCE" -ge "$REQUIRED_BALANCE" ]]; then
        echo "Have enough SUI for deployment"
        return
    fi

    REQUIRED_SUI=$(format_sui_amount $REQUIRED_BALANCE)
    echo "Need $REQUIRED_SUI SUI for deployment"
    echo "Requesting tokens from faucet..."

    FAUCET_OUTPUT=$(sui client faucet 2>&1)
    if [[ "$FAUCET_OUTPUT" =~ "Success" || "$FAUCET_OUTPUT" =~ "200 OK" ]]; then
        echo "Faucet request successful"
    fi

    echo "Waiting for transaction..."
    sleep 3

    NEW_TOTAL=$(get_balance_in_mist)
    NEW_TOTAL=${NEW_TOTAL:-0}
    NEW_SUI=$(format_sui_amount $NEW_TOTAL)

    if [[ "$NEW_TOTAL" -gt "$TOTAL_BALANCE" ]]; then
        GAINED=$((NEW_TOTAL - TOTAL_BALANCE))
        GAINED_SUI=$(format_sui_amount $GAINED)
        echo "Received $GAINED_SUI SUI"
        echo "New balance: $NEW_SUI SUI"

        if [[ "$NEW_TOTAL" -ge "$REQUIRED_BALANCE" ]]; then
            echo "Ready for deployment"
        else
            echo "Error: Need $REQUIRED_SUI SUI but only have $NEW_SUI SUI"
            exit 1
        fi
    else
        echo "Error: Balance did not increase"
        echo "Current balance: $TOTAL_SUI SUI"
        exit 1
    fi


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

if [[ "$LOCAL_TEST" == true ]]; then
echo "Deploying to local environment..."
else
echo "Deploying to $NETWORK..."
fi

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
