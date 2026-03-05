#!/bin/bash
set -euo pipefail

# Record a client payment and update their billing
# Usage: bash record-payment.sh <client_id> <crypto> <amount> <tx_hash> [--note "text"]
#
# Example:
#   bash record-payment.sh <CLIENT_NAME> ETH 0.11 0x2447f0a1... --note "February payment"
#   bash record-payment.sh <client> USDC 100 0xabc123... --note "First top-up"

WORKSPACE="$HOME/.openclaw/workspace"
MRB_DIR="$HOME/mrb-sh"

CLIENT_ID="${1:?Usage: record-payment.sh <client_id> <crypto> <amount> <tx_hash> [--note 'text']}"
CRYPTO="${2:?Missing: crypto (ETH, USDC, USDT)}"
AMOUNT="${3:?Missing: amount}"
TX_HASH="${4:?Missing: tx_hash}"
shift 4

NOTE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --note) NOTE="$2"; shift 2;;
        *) echo "Unknown: $1"; exit 1;;
    esac
done

BILLING_FILE="$MRB_DIR/data/clients/${CLIENT_ID}.json"
if [ ! -f "$BILLING_FILE" ]; then
    echo "❌ Client billing file not found: $BILLING_FILE"
    exit 1
fi

# Get current price for the crypto asset
CRYPTO_UPPER=$(echo "$CRYPTO" | tr '[:lower:]' '[:upper:]')

python3 << PYEOF
import json, urllib.request, sys
from datetime import datetime

client_id = "$CLIENT_ID"
crypto = "$CRYPTO_UPPER"
amount = float("$AMOUNT")
tx_hash = "$TX_HASH"
note = "$NOTE"

# Get price
if crypto in ("USDC", "USDT", "DAI"):
    price = 1.0
else:
    coin_ids = {"ETH": "ethereum", "BTC": "bitcoin", "SOL": "solana", "SKY": "maker"}
    coin_id = coin_ids.get(crypto)
    if not coin_id:
        print(f"⚠️  Unknown crypto '{crypto}' — set price to 0, update manually")
        price = 0
    else:
        try:
            r = urllib.request.urlopen(f"https://api.coingecko.com/api/v3/simple/price?ids={coin_id}&vs_currencies=usd")
            data = json.loads(r.read())
            price = data[coin_id]["usd"]
        except Exception as e:
            print(f"⚠️  Price fetch failed: {e}")
            price = 0

usd_value = round(amount * price, 2)

# Load billing
with open("$BILLING_FILE") as f:
    billing = json.load(f)

# Add payment
payment = {
    "date": datetime.utcnow().strftime("%Y-%m-%d"),
    "crypto": crypto,
    "amount_crypto": amount,
    "price_at_payment": price,
    "usd_value": usd_value,
    "tx_hash": tx_hash,
    "converted_to": "pending" if crypto not in ("USDC", "USDT") else crypto,
    "note": note or f"Payment from {client_id}"
}

if "payments" not in billing:
    billing["payments"] = []
billing["payments"].append(payment)

# Save
with open("$BILLING_FILE", "w") as f:
    json.dump(billing, f, indent=2)

print(f"✅ Payment recorded for {client_id}")
print(f"   {amount} {crypto} × \${price:,.2f} = \${usd_value:,.2f}")
print(f"   TX: {tx_hash[:16]}...")
if crypto not in ("USDC", "USDT"):
    print(f"   ⚠️  Convert {crypto} to USDC/USDT and update 'converted_to' field")
PYEOF
