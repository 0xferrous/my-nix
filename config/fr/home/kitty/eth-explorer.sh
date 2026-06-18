#!/usr/bin/env bash

# Get the address/tx hash from the first argument
VALUE="$1"

# Detect type based on length (addresses are 42 chars, tx hashes are 66 chars)
if [ ${#VALUE} -eq 42 ]; then
    TYPE="address"
elif [ ${#VALUE} -eq 66 ]; then
    TYPE="tx"
else
    echo "Invalid Ethereum value: $VALUE"
    exit 1
fi

# Select explorer using fzf
EXPLORER=$(echo -e "Etherscan\nPolygonscan\nBSCscan\nArbiscan\nOptimism\nBase\nAvalanche" | fzf --prompt="Select explorer: " --height=40% --layout=reverse --border)

# Build the URL based on selection
case $EXPLORER in
    Etherscan)
        URL="https://etherscan.io/$TYPE/$VALUE"
        ;;
    Polygonscan)
        URL="https://polygonscan.com/$TYPE/$VALUE"
        ;;
    BSCscan)
        URL="https://bscscan.com/$TYPE/$VALUE"
        ;;
    Arbiscan)
        URL="https://arbiscan.io/$TYPE/$VALUE"
        ;;
    Optimism)
        URL="https://optimistic.etherscan.io/$TYPE/$VALUE"
        ;;
    Base)
        URL="https://basescan.org/$TYPE/$VALUE"
        ;;
    Avalanche)
        URL="https://snowtrace.io/$TYPE/$VALUE"
        ;;
    *)
        exit 1
        ;;
esac

# Open the URL
xdg-open "$URL"