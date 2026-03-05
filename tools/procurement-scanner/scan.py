#!/usr/bin/env python3
"""
SAM.gov Aviation/IT Procurement Scanner — BUDGET MODE
We only get 10 API calls/day (public tier). Every call counts.

Strategy:
  - 1 call/day, targeted: FAA-only via NAICS filter
  - 7-day lookback window (catches weekends)
  - Local dedup against seen.json so we never alert on the same opp twice
  - Post-filter titles/descriptions for relevance keywords
  - Queues a single digest notification if new matches found

Upgrade path: Register TukuDev on SAM.gov → 1,000/day → can broaden searches.
"""

import json
import os
import sys
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone
from pathlib import Path

WORKSPACE = Path(os.path.expanduser("~/.openclaw/workspace"))
DATA_DIR = WORKSPACE / "projects" / "procurement-scanner" / "data"
RESULTS_FILE = DATA_DIR / "latest-results.json"
SEEN_FILE = DATA_DIR / "seen.json"
HISTORY_FILE = DATA_DIR / "history.jsonl"
ENV_FILE = Path(os.path.expanduser("~/.openclaw/.env"))

# Keywords that make an opportunity relevant (matched against title + description)
TITLE_KEYWORDS = [
    "aviation", "faa", "aircraft", "airspace", "air traffic", "notam",
    "legacy modernization", "application modernization", "software modernization",
    "cloud migration", "digital transformation", "ai system", "artificial intelligence",
    "machine learning", "automation", "database modernization",
]

# NAICS codes for IT services — used in API query to pre-filter
IT_NAICS = [
    "541512",  # Computer Systems Design
    "541511",  # Custom Computer Programming
    "541519",  # Other Computer Related Services
]


def load_api_key():
    if not ENV_FILE.exists():
        sys.exit("ERROR: .env not found")
    for line in ENV_FILE.read_text().splitlines():
        if line.startswith("SAMGOV_API_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("ERROR: SAMGOV_API_KEY not found")


def load_seen():
    if SEEN_FILE.exists():
        return set(json.loads(SEEN_FILE.read_text()))
    return set()


def save_seen(seen):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    SEEN_FILE.write_text(json.dumps(sorted(seen)))


def search_sam(api_key, posted_from, posted_to, naics_code=None):
    """Single API call. Returns opportunities list or None on error."""
    params = {
        "api_key": api_key,
        "postedFrom": posted_from,
        "postedTo": posted_to,
        "limit": "100",
        "offset": "0",
    }
    if naics_code:
        params["ncode"] = naics_code

    url = f"https://api.sam.gov/opportunities/v2/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})

    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        return data.get("opportunitiesData", []), data.get("totalRecords", 0)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if "throttled" in body.lower():
            print("RATE LIMITED — skipping today")
            return None, 0
        print(f"HTTP {e.code}: {body[:200]}")
        return None, 0
    except Exception as e:
        print(f"ERROR: {e}")
        return None, 0


def is_relevant(opp):
    """Post-filter for relevance. Cheap — no API call."""
    title = (opp.get("title") or "").lower()
    desc = (opp.get("description") or "").lower()
    text = title + " " + desc

    # Direct FAA/aviation hit
    agency = (opp.get("fullParentPathName") or "").upper()
    if "FAA" in agency or "FEDERAL AVIATION" in agency:
        return True, "FAA"

    # Keyword in title (high signal)
    for kw in TITLE_KEYWORDS:
        if kw in title:
            return True, f"title:{kw}"

    # Keyword in description (lower signal, need 2+ matches)
    matches = [kw for kw in TITLE_KEYWORDS if kw in desc]
    if len(matches) >= 2:
        return True, f"desc:{'+'.join(matches[:2])}"

    return False, ""


def format_opp(opp, reason):
    return {
        "id": opp.get("noticeId", ""),
        "title": opp.get("title", "?"),
        "agency": (opp.get("fullParentPathName") or "?")[:80],
        "type": opp.get("type", "?"),
        "solNum": opp.get("solicitationNumber", ""),
        "posted": opp.get("postedDate", ""),
        "deadline": opp.get("responseDeadLine", "N/A"),
        "match": reason,
        "url": f"https://sam.gov/opp/{opp.get('noticeId', '')}/view",
    }


def main():
    api_key = load_api_key()
    seen = load_seen()
    now = datetime.now(timezone.utc)

    # 7-day lookback, 1 API call
    to_date = now.strftime("%m/%d/%Y")
    from_date = (now - timedelta(days=7)).strftime("%m/%d/%Y")
    print(f"Scanning {from_date} → {to_date} (1 API call, budget mode)")

    opps, total = search_sam(api_key, from_date, to_date)
    if opps is None:
        sys.exit(0)  # Rate limited — silent exit, try tomorrow

    print(f"Fetched {len(opps)} of {total} total opportunities")

    # Post-filter + dedup
    new_matches = []
    for opp in opps:
        notice_id = opp.get("noticeId", "")
        if notice_id in seen:
            continue
        is_rel, reason = is_relevant(opp)
        if is_rel:
            new_matches.append(format_opp(opp, reason))
            seen.add(notice_id)

    print(f"New relevant matches: {len(new_matches)} (already seen: {len(seen)} total)")

    # Save state
    save_seen(seen)
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    result = {
        "scanned_at": now.isoformat(),
        "date_range": f"{from_date} - {to_date}",
        "total_scanned": len(opps),
        "new_relevant": len(new_matches),
        "opportunities": new_matches,
    }
    RESULTS_FILE.write_text(json.dumps(result, indent=2))

    # History
    with open(HISTORY_FILE, "a") as f:
        f.write(json.dumps({
            "date": now.strftime("%Y-%m-%d"),
            "scanned": len(opps),
            "new": len(new_matches),
        }) + "\n")

    # Print for notification wrapper
    if new_matches:
        print(f"\n🔍 {len(new_matches)} new opportunities:")
        for o in new_matches[:5]:
            print(f"  📋 {o['title'][:70]}")
            print(f"     {o['agency'][:50]} | Deadline: {o['deadline']}")
            print()

    return new_matches


if __name__ == "__main__":
    main()
