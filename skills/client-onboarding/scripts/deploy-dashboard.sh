#!/bin/bash
set -euo pipefail

# Deploy or update a client's dashboard page
# Usage: bash deploy-dashboard.sh <client_name>

MRB_DIR="$HOME/mrb-sh"
WORKSPACE="$HOME/.openclaw/workspace"
CLIENT_ID="${1:?Usage: deploy-dashboard.sh <client_name>}"

BILLING_FILE="$MRB_DIR/data/clients/${CLIENT_ID}.json"
WEB_DIR="$MRB_DIR/public/client/${CLIENT_ID}"

if [ ! -f "$BILLING_FILE" ]; then
    echo "❌ Billing file not found: $BILLING_FILE"
    echo "   Run provision.sh first"
    exit 1
fi

mkdir -p "$WEB_DIR"

# Read client name from billing JSON
CLIENT_NAME=$(python3 -c "import json; print(json.load(open('$BILLING_FILE'))['name'])")

cat > "$WEB_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CLIENT_NAME — Dashboard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, system-ui, 'Segoe UI', sans-serif; background: #0a0a0a; color: #e0e0e0; padding: 2rem; }
  .auth-wall { display: none; text-align: center; padding: 4rem 2rem; color: #444; }
  h1 { font-size: 1.5rem; font-weight: 600; color: #fff; margin-bottom: .25rem; }
  .sub { color: #666; font-size: .9rem; margin-bottom: 2rem; }
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
  .card { background: #141414; border: 1px solid #222; border-radius: 10px; padding: 1.25rem; }
  .card .label { color: #666; font-size: .75rem; text-transform: uppercase; letter-spacing: .06em; }
  .card .value { font-size: 1.6rem; font-weight: 600; color: #fff; margin-top: .4rem; }
  .card .unit { font-size: .85rem; color: #555; }
  .badge { display: inline-block; padding: .2rem .6rem; border-radius: 99px; font-size: .75rem; font-weight: 500; }
  .badge.active { background: #0d3320; color: #4ade80; }
  .badge.setup { background: #332d0d; color: #facc15; }
  .badge.offline { background: #330d0d; color: #f87171; }
  .section { margin-top: 2rem; }
  .section h2 { font-size: 1rem; color: #888; margin-bottom: 1rem; font-weight: 500; }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: .6rem .75rem; border-bottom: 1px solid #1a1a1a; font-size: .85rem; }
  th { color: #555; font-size: .7rem; text-transform: uppercase; letter-spacing: .05em; }
  .empty { text-align: center; padding: 2rem; color: #333; }
  .refresh { color: #444; font-size: .75rem; margin-top: 2rem; }
  .health { margin-top: 1rem; }
  .health-item { display: flex; align-items: center; gap: .5rem; padding: .4rem 0; font-size: .85rem; }
  .dot { width: 8px; height: 8px; border-radius: 50%; }
  .dot.ok { background: #4ade80; }
  .dot.warn { background: #facc15; }
  .dot.fail { background: #f87171; }
</style>
</head>
<body>

<div class="auth-wall" id="auth-wall">Not found</div>

<div id="app" style="display:none">
  <div style="display:flex;align-items:center;gap:1rem;margin-bottom:.25rem">
    <h1 id="client-name">CLIENT_NAME</h1>
    <span class="badge active" id="status-badge">Active</span>
  </div>
  <p class="sub" id="client-sub">Managed OpenClaw Instance</p>

  <div class="cards" id="cards"></div>

  <div class="section" id="health-section" style="display:none">
    <h2>System Health</h2>
    <div class="health" id="health-checks"></div>
  </div>

  <div class="section">
    <h2>Payments</h2>
    <table id="payments-table">
      <thead><tr><th>Date</th><th>Amount</th><th>Note</th></tr></thead>
      <tbody id="payments-body"></tbody>
    </table>
  </div>

  <div class="section">
    <h2>API Usage</h2>
    <table id="usage-table">
      <thead><tr><th>Date</th><th>Input Tokens</th><th>Output Tokens</th><th>Cost</th></tr></thead>
      <tbody id="usage-body"></tbody>
    </table>
  </div>

  <p class="refresh" id="refresh-time"></p>
</div>

<script>
const params = new URLSearchParams(window.location.search);
const key = params.get('key');
if (!key) {
  document.getElementById('auth-wall').style.display = 'block';
} else {
  document.getElementById('app').style.display = 'block';
  load();
}

async function load() {
  try {
    const clientId = window.location.pathname.split('/').filter(Boolean).pop();
    const r = await fetch(`/api/clients/${clientId}/usage?key=${key}`);
    if (!r.ok) { document.getElementById('auth-wall').style.display = 'block'; document.getElementById('app').style.display = 'none'; return; }
    const d = await r.json();
    render(d);
  } catch(e) { console.error(e); }
}

function render(d) {
  document.getElementById('client-name').textContent = d.name || 'CLIENT_NAME';
  
  const totalPaid = (d.payments || []).reduce((s, p) => s + (p.amount_eth || 0), 0);
  const totalCost = (d.apiUsage || []).reduce((s, u) => s + (u.cost || 0), 0);
  const vpsCost = d.monthlyCosts?.vps || 0;
  
  document.getElementById('cards').innerHTML = `
    <div class="card"><div class="label">VPS Cost</div><div class="value">$${vpsCost}</div><div class="unit">/month</div></div>
    <div class="card"><div class="label">API Cost (MTD)</div><div class="value">$${totalCost.toFixed(2)}</div><div class="unit">this month</div></div>
    <div class="card"><div class="label">Total Paid</div><div class="value">${totalPaid.toFixed(4)}</div><div class="unit">ETH</div></div>
    <div class="card"><div class="label">Since</div><div class="value">${d.startDate || '—'}</div><div class="unit">start date</div></div>
  `;
  
  const pb = document.getElementById('payments-body');
  pb.innerHTML = (d.payments || []).length === 0 
    ? '<tr><td colspan="3" class="empty">No payments yet</td></tr>'
    : (d.payments || []).map(p => `<tr><td>${p.date}</td><td>${p.amount_eth} ETH</td><td>${p.note || ''}</td></tr>`).join('');
  
  const ub = document.getElementById('usage-body');
  ub.innerHTML = (d.apiUsage || []).length === 0
    ? '<tr><td colspan="4" class="empty">No usage data yet</td></tr>'
    : (d.apiUsage || []).map(u => `<tr><td>${u.date}</td><td>${(u.input_tokens||0).toLocaleString()}</td><td>${(u.output_tokens||0).toLocaleString()}</td><td>$${(u.cost||0).toFixed(2)}</td></tr>`).join('');
  
  document.getElementById('refresh-time').textContent = 'Last refreshed: ' + new Date().toLocaleString();
}

// Auto-refresh every 60s
setInterval(load, 60000);
</script>
</body>
</html>
HTMLEOF

# Replace placeholder
sed -i "s/CLIENT_NAME/${CLIENT_NAME}/g" "$WEB_DIR/index.html"

echo "✅ Dashboard deployed: <YOUR_DOMAIN>/client/${CLIENT_ID}/"
echo "   URL: https://<YOUR_DOMAIN>/client/${CLIENT_ID}/?key=\$MRB_API_KEY"
