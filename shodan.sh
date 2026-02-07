#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 \"shodan query\""
    exit 1
fi

RAW_QUERY="$1"

# ---------------------------
# URL encode
# ---------------------------
urlencode() {
    python3 - "$1" << 'EOF'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
EOF
}

ENCODED_QUERY=$(urlencode "$RAW_QUERY")

echo "[+] Raw query     : $RAW_QUERY"
echo "[+] Encoded query : $ENCODED_QUERY"
echo

# ---------------------------
# Get ports
# ---------------------------
echo "[+] Fetching ports..."

PORTS=$(curl -s \
"https://www.shodan.io/search/facet?query=${ENCODED_QUERY}&facet=port" \
| perl -nle 'print $1 if /<strong>(.*?)<\/strong>/')

[ -z "$PORTS" ] && echo "[-] No ports found" && exit 1

echo "=== Open Ports ==="
echo "$PORTS"
echo

# ---------------------------
# Mode selection
# ---------------------------
echo "1) Query single port"
echo "2) Query ALL ports"
read -p "Choose option [1/2]: " MODE

# ---------------------------
# Single port mode
# ---------------------------
if [ "$MODE" = "1" ]; then
    read -p "Enter port: " PORT
    [ -z "$PORT" ] && echo "[-] No port selected" && exit 1

    IPS=$(curl -s \
    "https://www.shodan.io/search/facet?query=${ENCODED_QUERY}+port%3A${PORT}&facet=ip" \
    | perl -nle 'print $1 if /<strong>(.*?)<\/strong>/')

    [ -z "$IPS" ] && echo "[-] No IPs found" && exit 1

    RESULT=$(echo "$IPS" | sed "s/$/:$PORT/")

# ---------------------------
# ALL ports mode
# ---------------------------
elif [ "$MODE" = "2" ]; then
    RESULT=""

    for PORT in $PORTS; do
        echo "[+] Fetching IPs for port $PORT..."

        IPS=$(curl -s \
        "https://www.shodan.io/search/facet?query=${ENCODED_QUERY}+port%3A${PORT}&facet=ip" \
        | perl -nle 'print $1 if /<strong>(.*?)<\/strong>/')

        [ -z "$IPS" ] && continue

        IPS_WITH_PORT=$(echo "$IPS" | sed "s/$/:$PORT/")
        RESULT+="$IPS_WITH_PORT"$'\n'
    done

    [ -z "$RESULT" ] && echo "[-] No IPs found for any port" && exit 1

else
    echo "[-] Invalid option"
    exit 1
fi

# ---------------------------
# Output
# ---------------------------
echo
echo "=== IP:PORT RESULTS ==="
echo "$RESULT"
echo

read -p "Save to file: " FILE
if [ -n "$FILE" ]; then
    echo "$RESULT" > "$FILE"
    echo "[+] Saved to $FILE"
fi

