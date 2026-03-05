#!/usr/bin/env python3
"""
Flight search + hidden city fare finder using Travelpayouts/Aviasales API.
Works for Russian-origin flights where western search engines fail.

Usage:
  python3 search.py MOW SZX 2026-03-06              # Direct search
  python3 search.py MOW SZX 2026-03-06 --hidden-city # Find hidden city fares
  python3 search.py MOW SZX 2026-03-06 --flexible 3  # Check +/- 3 days
  python3 search.py MOW SZX 2026-03 --month           # Cheapest in month
"""

import argparse
import json
import sys
from datetime import datetime, timedelta
from urllib.request import Request, urlopen
from urllib.parse import urlencode

# Travelpayouts demo token (cached prices, no auth needed)
TOKEN = "321d6a221f8926b5ec41ae89a3b2ae7b"
BASE_V3 = "https://api.travelpayouts.com/aviasales/v3/prices_for_dates"
BASE_V1_CHEAP = "https://api.travelpayouts.com/v1/prices/cheap"

# Common connecting hubs in Asia for hidden city searches
HIDDEN_CITY_TARGETS = {
    # If destination is in South China / Pearl River Delta
    "SZX": ["BKK", "SGN", "KUL", "SIN", "MNL", "JKT", "HAN", "RGN", "PNH", "DPS"],
    "CAN": ["BKK", "SGN", "KUL", "SIN", "MNL", "JKT", "HAN", "RGN", "PNH", "DPS"],
    "HKG": ["BKK", "SGN", "KUL", "SIN", "MNL", "JKT", "HAN", "RGN", "PNH", "DPS"],
    # Default: SE Asian destinations that commonly connect through Chinese hubs
    "_default": ["BKK", "KUL", "SIN", "SGN", "MNL", "JKT", "DPS", "HAN"],
}

AIRLINE_NAMES = {
    "CA": "Air China", "CZ": "China Southern", "MU": "China Eastern",
    "HU": "Hainan Airlines", "SU": "Aeroflot", "S7": "S7 Airlines",
    "DP": "Pobeda", "G9": "Air Arabia", "DV": "SCAT Airlines",
    "HY": "Uzbekistan Airways", "KC": "Air Astana", "TK": "Turkish Airlines",
    "EK": "Emirates", "QR": "Qatar Airways", "EY": "Etihad",
    "3U": "Sichuan Airlines", "ZH": "Shenzhen Airlines", "SC": "Shandong Airlines",
    "FM": "Shanghai Airlines", "MF": "Xiamen Air",
}


def api_get(url, params):
    params["token"] = TOKEN
    full_url = f"{url}?{urlencode(params)}"
    req = Request(full_url)
    req.add_header("X-Access-Token", TOKEN)
    try:
        resp = urlopen(req, timeout=15)
        return json.loads(resp.read())
    except Exception as e:
        return {"success": False, "error": str(e)}


def search_direct(origin, dest, date, limit=10):
    """Search for flights on a specific date."""
    params = {
        "origin": origin,
        "destination": dest,
        "departure_at": date,
        "one_way": "true",
        "currency": "usd",
        "limit": str(limit),
        "sorting": "price",
    }
    return api_get(BASE_V3, params)


def search_month(origin, dest, month):
    """Search for cheapest flights in a month."""
    params = {
        "origin": origin,
        "destination": dest,
        "depart_date": month,
        "currency": "USD",
    }
    return api_get(BASE_V1_CHEAP, params)


def format_flight(f, prefix=""):
    airline_code = f.get("airline", "??")
    airline = AIRLINE_NAMES.get(airline_code, airline_code)
    price = f.get("price", "?")
    stops = f.get("transfers", 0)
    dur = f.get("duration_to", 0)
    dep = f.get("departure_at", "?")
    orig = f.get("origin_airport", "?")
    dest = f.get("destination_airport", "?")
    gate = f.get("gate", "")

    stop_text = "direct" if stops == 0 else f"{stops} stop{'s' if stops > 1 else ''}"
    dur_text = f"{dur // 60}h{dur % 60:02d}m" if dur else "?"
    dep_short = dep[:16].replace("T", " ") if dep != "?" else "?"

    line = f"{prefix}${price:>6} | {airline:<18} | {orig}→{dest} | {stop_text:<8} | {dur_text} | {dep_short}"
    if gate:
        line += f" | {gate}"
    return line


def find_hidden_city(origin, dest, date):
    """
    Hidden city fare finder.
    
    Searches for flights from origin to destinations BEYOND dest,
    that commonly connect through dest (or nearby airports).
    If any are cheaper than the direct fare, that's a hidden city opportunity.
    """
    # First get the direct price
    print(f"\n🔍 Searching direct: {origin}→{dest} on {date}")
    direct = search_direct(origin, dest, date, limit=3)
    direct_prices = direct.get("data", [])

    if direct_prices:
        best_direct = direct_prices[0]["price"]
        print(f"   Best direct price: ${best_direct}")
        for f in direct_prices[:3]:
            print(format_flight(f, "   "))
    else:
        best_direct = float("inf")
        print("   No direct flights found")

    # Search beyond destinations
    targets = HIDDEN_CITY_TARGETS.get(dest, HIDDEN_CITY_TARGETS["_default"])
    print(f"\n🕵️ Checking {len(targets)} hidden city routes (flights through {dest} area)...")

    hidden_deals = []
    for beyond in targets:
        result = search_direct(origin, beyond, date, limit=3)
        flights = result.get("data", [])
        if flights:
            cheapest = flights[0]
            price = cheapest["price"]
            savings = best_direct - price
            if savings > 0:
                hidden_deals.append({
                    "beyond": beyond,
                    "flight": cheapest,
                    "savings": savings,
                    "pct": round(savings / best_direct * 100) if best_direct != float("inf") else 0,
                })
            status = f"${price}" + (f" (SAVE ${savings}!)" if savings > 0 else "")
        else:
            status = "no flights"
        print(f"   {origin}→{beyond}: {status}")

    # Summary
    if hidden_deals:
        hidden_deals.sort(key=lambda x: x["flight"]["price"])
        print(f"\n🎯 HIDDEN CITY OPPORTUNITIES ({len(hidden_deals)} found):")
        print(f"   Direct {origin}→{dest}: ${best_direct}")
        print(f"   {'─' * 60}")
        for d in hidden_deals:
            f = d["flight"]
            airline = AIRLINE_NAMES.get(f["airline"], f["airline"])
            print(f"   ${f['price']:>6} | {origin}→{d['beyond']} via {dest} area | {airline} | SAVE ${d['savings']} ({d['pct']}%)")
            print(f"          Book on aviasales: {origin}→{d['beyond']}, skip last leg")
        print(f"\n   ⚠️  Hidden city rules: carry-on only, no checked bags, one-way only")
    else:
        print(f"\n   ✅ No hidden city deals found — the direct fare is already competitive")

    return hidden_deals


def main():
    parser = argparse.ArgumentParser(description="Flight search + hidden city finder (Aviasales/Travelpayouts)")
    parser.add_argument("origin", help="Origin IATA code (e.g., MOW)")
    parser.add_argument("dest", help="Destination IATA code (e.g., SZX)")
    parser.add_argument("date", help="Date (YYYY-MM-DD) or month (YYYY-MM)")
    parser.add_argument("--hidden-city", action="store_true", help="Find hidden city fares")
    parser.add_argument("--flexible", type=int, default=0, help="Check +/- N days")
    parser.add_argument("--month", action="store_true", help="Search whole month")
    parser.add_argument("--limit", type=int, default=10, help="Max results per search")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    origin = args.origin.upper()
    dest = args.dest.upper()

    if args.month:
        print(f"\n📅 Cheapest in {args.date}: {origin}→{dest}")
        result = search_month(origin, dest, args.date)
        if args.json:
            print(json.dumps(result, indent=2))
        elif result.get("success") and result.get("data", {}).get(dest):
            for k, v in sorted(result["data"][dest].items(), key=lambda x: x[1]["price"]):
                print(f"  ${v['price']:>6} | {AIRLINE_NAMES.get(v.get('airline',''), v.get('airline','??')):<18} | {v.get('departure_at','?')[:10]} | stops: {k}")
        else:
            print("  No results")
        return

    if args.hidden_city:
        find_hidden_city(origin, dest, args.date)
        return

    # Flexible date search
    dates = [args.date]
    if args.flexible > 0:
        base = datetime.strptime(args.date, "%Y-%m-%d")
        for i in range(1, args.flexible + 1):
            dates.append((base + timedelta(days=i)).strftime("%Y-%m-%d"))
            dates.append((base - timedelta(days=i)).strftime("%Y-%m-%d"))
        dates.sort()

    for date in dates:
        print(f"\n✈️  {origin}→{dest} on {date}")
        result = search_direct(origin, dest, date, args.limit)
        if args.json:
            print(json.dumps(result, indent=2))
        elif result.get("success") and result.get("data"):
            for f in result["data"]:
                print(format_flight(f, "   "))
        else:
            print("   No flights found")


if __name__ == "__main__":
    main()
