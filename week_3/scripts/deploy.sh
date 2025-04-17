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
    # Redirect stderr to stdout for capture, then redirect combined output to /dev/null for check
    if ! sui client active-address > /dev/null 2>&1
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
        # Run the command - capture stderr to avoid clutter unless debugging
        output=$(sui client gas "$ACTIVE_ADDRESS" 2>/dev/null)
        if [[ -z "$output" ]]; then
            echo "0" # No output probably means no gas coins
            return
        fi

        # Use awk to parse the table:
        local total
        total=$(echo "$output" | awk -F'│' '/^│ 0x/ {gsub(/[[:space:]]/,"",$3); total+=$3} END {print total+0}')

        # Fallback in case awk produced no output or failed
        echo "${total:-0}"
    }

    format_sui_amount() {
        local mist=$1
        # Check if mist is a valid integer
        if ! [[ "$mist" =~ ^[0-9]+$ ]]; then
            echo "0.00 (invalid input)"
            return
        fi
        # Use bc for floating-point division
        if [[ "$mist" -le 0 ]]; then
            echo "0.00"
            return
        fi
        # Ensure scale is sufficient for small amounts, format to 2 decimal places
        printf "%.2f" "$(echo "scale=10; $mist/1000000000" | bc)"
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
    # Check if faucet request likely succeeded (needs refinement based on actual output)
    if [[ "$FAUCET_OUTPUT" =~ "Success" || "$FAUCET_OUTPUT" =~ "200 OK" || "$FAUCET_OUTPUT" =~ "Request handling in progress" ]]; then
        echo "Faucet request potentially successful..."
    else
        echo "Warning: Faucet request may have failed. Output:"
        echo "$FAUCET_OUTPUT"
        # Optionally exit here if faucet is critical and failed
        # exit 1
    fi

    echo "Waiting for transaction to process..."
    sleep 5 # Increased wait time slightly

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
            echo "Error: Faucet request succeeded but balance ($NEW_SUI SUI) is still less than required ($REQUIRED_SUI SUI)."
            exit 1
        fi
    else
        echo "Error: Balance did not increase after faucet request."
        echo "Current balance: $TOTAL_SUI SUI"
        echo "Faucet output was:"
        echo "$FAUCET_OUTPUT"
        exit 1
    fi
}

# Function to switch network
switch_network() {
    local target_network=$1
    echo "Switching to $target_network..."
    if ! sui client switch --env "$target_network"; then
        echo "Error: Failed to switch to network '$target_network'."
        exit 1
    fi
    echo "Switched to $target_network."
}

# ---- Determine Network Name for Files ----
# Use 'local' for file names if --local flag is set, otherwise use the specified network
if [[ "$LOCAL_TEST" == true ]]; then
    JSON_NETWORK_NAME="local"
else
    JSON_NETWORK_NAME="$NETWORK"
fi

# ---- Environment Setup ----
if [[ "$LOCAL_TEST" == true ]]
then
    echo "Using local test environment..."
    # No network switch needed, just check wallet
    check_wallet
else
    # Validate network name for non-local deployments
    if [[ ! "$NETWORK" =~ ^(devnet|testnet|mainnet)$ ]]
    then
        echo "Error: Network must be devnet, testnet, or mainnet (provided: '$NETWORK')"
        exit 1
    fi
    # Switch to specified network and check wallet
    switch_network "$NETWORK"
    check_wallet
fi

# ---- Deployment ----
if [[ "$LOCAL_TEST" == true ]]; then
    echo "Deploying to local environment..."
else
    echo "Deploying to $NETWORK..."
fi

# Navigate to Move project directory (relative to script location)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR="$SCRIPT_DIR/../arturcoin"

echo "Changing directory to $PROJECT_DIR"
cd "$PROJECT_DIR" || { echo "Error: Failed to change directory to $PROJECT_DIR"; exit 1; }

# Build the contract
echo "Building contract..."
if ! sui move build; then
    echo "Error: sui move build failed."
    exit 1
fi
echo "Build successful."

# Publish the contract
echo "Publishing contract..."
COMMAND="sui client publish --gas-budget 10000000000" # 10 SUI

if [[ "$LOCAL_TEST" == true ]]
then
    echo "Local test mode: Publishing to local network..."
    # Add any specific flags for local publish if needed, e.g., --skip-dependency-verification might be okay locally
    # COMMAND="$COMMAND --skip-dependency-verification"
else
    echo "Publishing to $NETWORK..."
    # Consider adding --skip-dependency-verification or --verify-deps based on needs for non-local
fi

# --- MODIFIED PUBLISH EXECUTION WITH DEBUGGING ---
echo "DEBUG: Running command: $COMMAND"
# Execute the command and capture its output (stdout and stderr combined)
PUBLISH_OUTPUT=$(eval "$COMMAND" 2>&1)
PUBLISH_EXIT_CODE=$? # Capture exit code IMMEDIATELY
echo "DEBUG: Publish command finished with exit code: $PUBLISH_EXIT_CODE"

# Explicitly check exit code
if [[ "$PUBLISH_EXIT_CODE" -ne 0 ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERROR: 'sui client publish' failed with exit code $PUBLISH_EXIT_CODE!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "-------------------- Failed Publish Output START --------------------"
    echo "$PUBLISH_OUTPUT" # Print captured output (which includes stderr now)
    echo "-------------------- Failed Publish Output END ----------------------"
    exit 1 # Exit on failure
fi

# If we reach here, publish command returned exit code 0
echo "Publish command seemingly successful (Exit Code 0). Full Output:"
echo "-------------------- Publish Output START --------------------"
echo "$PUBLISH_OUTPUT"
echo "-------------------- Publish Output END ----------------------"
# --- END MODIFIED PUBLISH EXECUTION ---


# Function to extract hex IDs (keep as is, but it now processes output from successful command)
extract_id() {
    local output="$1"
    local pattern="$2" # e.g., "Published Objects" or "Created Objects"
    local n="$3"       # e.g., 1 for first ID, 2 for second

    # Try to find the pattern and get the Nth 64-char hex string after it
    # This is still fragile if output format changes significantly
    local id
    # Look for the pattern, take the next few lines, find hex strings, get the Nth one
    id=$(echo "$output" | grep -A 5 "$pattern" | grep -o '0x[a-fA-F0-9]\{64\}' | sed -n "${n}p")

    # Fallback: If the pattern wasn't found or didn't yield results, just search the whole output
    if [[ -z "$id" ]]; then
         echo "DEBUG: Pattern '$pattern' not found or no ID after it. Searching entire output." >&2
         id=$(echo "$output" | grep -o '0x[a-fA-F0-9]\{64\}' | sed -n "${n}p")
    fi
    echo "$id"
}

# ---- Extract IDs ----
echo "Extracting deployment IDs..."
# Note: Adjust '1' and '2' if the order changes in publish output
PACKAGE_ID=$(extract_id "$PUBLISH_OUTPUT" "Published Objects" "1")
# CoinManager is usually the second *Created* object after the UpgradeCap
COIN_MANAGER_ID=$(extract_id "$PUBLISH_OUTPUT" "Created Objects" "2")

# ---- Verify IDs ----
if [[ -z "$PACKAGE_ID" ]] || [[ -z "$COIN_MANAGER_ID" ]]
then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Error: Failed to extract IDs from successful publish output."
    echo "The 'sui client publish' command finished without error (Exit Code 0),"
    echo "but the expected patterns ('Published Objects', 'Created Objects')"
    echo "or the 0x... IDs were not found in the expected places."
    echo "Check the full publish output above for the correct structure and IDs."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Attempted to extract:"
    echo "Package ID: $PACKAGE_ID"
    echo "Coin Manager ID: $COIN_MANAGER_ID"
    exit 1
fi

echo "Successfully extracted IDs:"
echo "Package ID: $PACKAGE_ID"
echo "Coin Manager ID: $COIN_MANAGER_ID"

# ---- Update Configuration Files ----
# Navigate back to the parent directory where 'deployments' and 'arturcoin-frontend' are expected
cd "$SCRIPT_DIR/.." || { echo "Error: Failed to navigate back to project root from $SCRIPT_DIR"; exit 1; }

# Create deployments directory if it doesn't exist
DEPLOYMENTS_DIR="deployments"
mkdir -p "$DEPLOYMENTS_DIR"

# Use JSON_NETWORK_NAME for the file name
JSON_FILE="$DEPLOYMENTS_DIR/$JSON_NETWORK_NAME.json"
echo "Updating deployment file: $JSON_FILE"

# Save to JSON file
cat > "$JSON_FILE" << EOF
{
  "packageId": "$PACKAGE_ID",
  "coinManagerId": "$COIN_MANAGER_ID",
  "network": "$JSON_NETWORK_NAME",
  "deploymentDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Update frontend .env file
FRONTEND_ENV_FILE="arturcoin-frontend/.env"
echo "Updating frontend environment file: $FRONTEND_ENV_FILE"
# Use JSON_NETWORK_NAME for VITE_NETWORK as well
cat > "$FRONTEND_ENV_FILE" << EOF
VITE_NETWORK=$JSON_NETWORK_NAME
VITE_PACKAGE_ID=$PACKAGE_ID
VITE_COIN_MANAGER_ID=$COIN_MANAGER_ID
EOF

# ---- Final Output ----
echo # Newline for readability
if [[ "$LOCAL_TEST" == true ]]
then
    echo "Local test deployment completed!"
else
    echo "Deployment to $NETWORK successful!"
fi

echo "Network used for files: $JSON_NETWORK_NAME"
echo "Package ID: $PACKAGE_ID"
echo "Coin Manager ID: $COIN_MANAGER_ID"
echo
echo "Configuration files updated:"
echo "- $JSON_FILE"
echo "- $FRONTEND_ENV_FILE"

# Print instructions for testing
if [[ "$LOCAL_TEST" == true ]]
then
    echo
    echo "Local test mode: Files were updated with the generated IDs."
    echo "Remember to restart your frontend dev server if it was running."
fi

echo
echo "Deployment script finished."
exit 0 # Explicitly exit with success
