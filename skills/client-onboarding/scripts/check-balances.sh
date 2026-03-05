#!/bin/bash
set -euo pipefail

# Check all client balances and flag low/negative accounts
# Usage: bash check-balances.sh [--alert]
#   --alert: send Telegram messages to clients with low balance

MRB_DIR="$HOME/mrb-sh"
CLIENTS_DIR="$MRB_DIR/data/clients"
ALERT=false

[[ "${1:-}" == "--alert" ]] && ALERT=true

echo "=== Client Balance Report ==="
echo ""

python3 << 'PYEOF'
import json, glob, os, sys

clients_dir = os.path.expanduser("~/mrb-sh/data/clients")
alert = "--alert" in sys.argv

# Multipliers (keep in sync with client-usage.js)
MULT_VPS = 5.0
MULT_ANTHROPIC = 1.0
MULT_OTHER = 5.0

results = []

for f in sorted(glob.glob(os.path.join(clients_dir, "*.json"))):
    if os.path.basename(f) == "keys.json":
        continue
    try:
        data = json.load(open(f))
    except:
        continue
    
    client_id = data.get("client", os.path.basename(f).replace(".json", ""))
    name = data.get("name", client_id)
    
    # Total paid
    total_paid = sum(p.get("usd_value", 0) for p in data.get("payments", []))
    
    # Total billed (VPS * months * multiplier + API)
    from datetime import datetime
    start = datetime.strptime(data.get("startDate", "2026-01-01"), "%Y-%m-%d")
    days = max(1, (datetime.utcnow() - start).days)
    months = max(1, days / 30)
    
    vps_billed = data.get("monthlyCosts", {}).get("vps", 0) * MULT_VPS * months
    api_cost = sum(u.get("cost", 0) for u in data.get("apiUsage", []))
    total_billed = vps_billed + api_cost * MULT_ANTHROPIC  # simplified
    
    balance = total_paid - total_billed
    
    status = "🟢" if balance >= 50 else ("🟡" if balance >= 0 else "🔴")
    
    results.append({
        "id": client_id,
        "name": name,
        "status": status,
        "balance": balance,
        "paid": total_paid,
        "billed": total_billed,
        "monthly": data.get("monthlyCosts", {}).get("vps", 0) * MULT_VPS,
        "runway_months": balance / (data.get("monthlyCosts", {}).get("vps", 0) * MULT_VPS) if data.get("monthlyCosts", {}).get("vps", 0) > 0 else 0,
        "telegram": data.get("telegram", "")
    })

# Print
for r in results:
    print(f"{r['status']} {r['name']:<20} Balance: ${r['balance']:>8.2f}  |  Paid: ${r['paid']:>8.2f}  |  Billed: ${r['billed']:>8.2f}  |  Runway: {r['runway_months']:.1f}mo")

print()
total_balance = sum(r["balance"] for r in results)
total_paid = sum(r["paid"] for r in results)
total_billed = sum(r["billed"] for r in results)
print(f"Total across {len(results)} clients: Paid ${total_paid:.2f}, Billed ${total_billed:.2f}, Net balance ${total_balance:.2f}")

# Flag alerts
low = [r for r in results if r["balance"] < 50]
if low:
    print(f"\n⚠️  {len(low)} client(s) need top-up:")
    for r in low:
        print(f"   {r['name']} ({r['telegram']}): ${r['balance']:.2f} — ~{max(0,r['runway_months']):.1f} months remaining")

PYEOF
