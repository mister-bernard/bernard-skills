#!/usr/bin/env python3
"""
Twitter Listener v2 — Polls watchlist accounts, scores for reply-worthiness,
wakes Bernard to craft replies. Also generates a daily digest of interesting
tweets for content inspiration.

Usage: python3 skills/twitter/listener.py [--dry-run] [--digest]

Cron: */30 * * * * (every 30 min)
State: skills/twitter/listener-state.json
"""

import json, os, sys, time, subprocess, urllib.request, urllib.parse, urllib.error, re
from pathlib import Path
from datetime import datetime, timezone

SKILL_DIR = Path(__file__).parent
STATE_FILE = SKILL_DIR / "listener-state.json"
WATCHLIST_FILE = SKILL_DIR / "watchlist.json"
ENV_FILE = Path.home() / ".openclaw" / ".env"
OPENCLAW = "/home/openclaw/.npm-global/bin/openclaw"
DIGEST_FILE = Path.home() / ".openclaw" / "workspace" / "projects" / "twitter-strategy" / "daily-digest.md"

DRY_RUN = "--dry-run" in sys.argv
DIGEST_MODE = "--digest" in sys.argv
MAX_TWEETS_PER_RUN = 5
MAX_ACCOUNTS_PER_RUN = 15  # Check more accounts per cycle

# Keywords that signal high-relevance content for our pillars
RELEVANCE_KEYWORDS = {
    "high": [
        # AI agents / operations
        "agent", "agents", "autonomous", "orchestrat", "multi-agent", "agentic",
        "claude", "anthropic", "opus", "sonnet", "llm", "language model",
        "ai infra", "ai ops", "deploy", "production",
        # DeFi / crypto substance
        "defi", "protocol", "governance", "tokenomics", "smart contract",
        "yield", "liquidity", "onchain", "on-chain", "mev",
        # Hardware / edge
        "edge computing", "raspberry pi", "jetson", "sdr", "radio",
        "whisper", "speech", "transcription",
        # Org / work future
        "layoff", "headcount", "org chart", "hiring", "team size",
        "automation", "replaced", "workforce",
    ],
    "medium": [
        "startup", "founder", "build", "ship", "scale",
        "open source", "github", "repo",
        "cost", "pricing", "margin", "revenue",
        "safety", "alignment", "red team",
        "benchmark", "eval", "performance",
        "gpu", "inference", "training", "fine-tun",
    ],
    "negative": [
        # Low-value content to skip
        "giveaway", "airdrop", "free mint", "whitelist", "alpha call",
        "not financial advice", "dyor", "wagmi", "gm gm",
        "like and retweet", "follow me", "subscribe",
    ]
}

def load_env():
    env = {}
    try:
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    if k != 'SAP_ARIBA_PW':  # Skip problematic line
                        env[k] = v
    except Exception:
        pass
    return env

def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"last_seen": {}, "last_run": None, "user_ids": {}, "daily_top": []}

def save_state(state):
    state["last_run"] = datetime.now(timezone.utc).isoformat()
    STATE_FILE.write_text(json.dumps(state, indent=2))

def load_watchlist():
    return json.loads(WATCHLIST_FILE.read_text())["accounts"]

def api_get(url, bearer_token):
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {bearer_token}",
        "User-Agent": "MrBernard/1.0"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        print(f"  ⚠️  API error {e.code}: {body[:200]}", file=sys.stderr)
        return None

def resolve_user_ids(usernames, bearer_token):
    chunks = [usernames[i:i+100] for i in range(0, len(usernames), 100)]
    mapping = {}
    for chunk in chunks:
        joined = ",".join(chunk)
        data = api_get(f"https://api.x.com/2/users/by?usernames={joined}", bearer_token)
        if data and "data" in data:
            for u in data["data"]:
                mapping[u["username"].lower()] = u["id"]
    return mapping

def get_recent_tweets(user_id, since_id, bearer_token):
    params = {
        "max_results": "10",
        "tweet.fields": "created_at,text,public_metrics,conversation_id",
        "exclude": "retweets,replies"
    }
    if since_id:
        params["since_id"] = since_id
    qs = urllib.parse.urlencode(params)
    return api_get(f"https://api.x.com/2/users/{user_id}/tweets?{qs}", bearer_token)

def score_tweet(tweet, account):
    """Score a tweet's reply-worthiness (0-100). Higher bar than v1."""
    score = 0
    text = tweet.get("text", "").lower()
    metrics = tweet.get("public_metrics", {})
    
    # === NEGATIVE FILTERS (skip junk) ===
    for neg in RELEVANCE_KEYWORDS["negative"]:
        if neg in text:
            return 0  # Instant reject
    
    # Pure link dump or very short
    if text.startswith("http") and len(text.split()) < 5:
        return 0
    if len(text) < 30:
        return 0
    
    # === RELEVANCE SCORING (most important) ===
    high_hits = sum(1 for kw in RELEVANCE_KEYWORDS["high"] if kw in text)
    med_hits = sum(1 for kw in RELEVANCE_KEYWORDS["medium"] if kw in text)
    
    score += min(high_hits * 12, 36)  # Up to 36 pts from high-relevance keywords
    score += min(med_hits * 6, 18)    # Up to 18 pts from medium keywords
    
    # === ACCOUNT PRIORITY ===
    if account["priority"] == "high": score += 15
    elif account["priority"] == "medium": score += 8
    
    # === ENGAGEMENT (visibility for our reply) ===
    likes = metrics.get("like_count", 0)
    replies = metrics.get("reply_count", 0)
    retweets = metrics.get("retweet_count", 0)
    
    if likes > 5000: score += 15
    elif likes > 1000: score += 10
    elif likes > 100: score += 5
    
    # High reply count = active conversation
    if replies > 50: score += 10
    elif replies > 10: score += 5
    
    # === CONTENT QUALITY SIGNALS ===
    # Questions invite replies
    if "?" in tweet.get("text", ""): score += 8
    
    # Takes/opinions (strong starters)
    opinion_starters = ["hot take", "unpopular opinion", "controversial", "i think", 
                        "the problem with", "the truth is", "nobody talks about",
                        "most people don't", "here's what"]
    for starter in opinion_starters:
        if starter in text:
            score += 10
            break
    
    # Substantive length (not too short, not a wall)
    word_count = len(text.split())
    if 20 < word_count < 100: score += 5
    
    # Thread starters (good for yarn-style response)
    if "🧵" in text or "thread" in text or "1/" in text:
        score += 5
    
    return max(0, min(100, score))

def format_digest(top_tweets):
    """Generate a markdown digest of today's best tweets."""
    if not top_tweets:
        return None
    
    lines = [f"# Twitter Digest — {datetime.now(timezone.utc).strftime('%Y-%m-%d')}\n"]
    lines.append(f"Top {len(top_tweets)} tweets from watchlist (sorted by relevance score)\n")
    
    for i, item in enumerate(top_tweets[:15], 1):
        # Handle both scored format {"tweet":..., "account":...} and daily_top format {"username":..., "text":...}
        if "tweet" in item:
            text = item["tweet"]["text"][:200].replace("\n", " ")
            uname = item["account"]["username"]
            s = item["score"]
            likes = item["tweet"].get("public_metrics", {}).get("like_count", 0)
            tid = item["tweet"]["id"]
            cat = item["account"].get("category", "")
        else:
            text = item.get("text", "")[:200].replace("\n", " ")
            uname = item.get("username", "?")
            s = item.get("score", 0)
            likes = item.get("likes", 0)
            tid = item.get("id", "?")
            cat = ""
        lines.append(f"### {i}. @{uname} (score: {s}, ❤️ {likes})")
        lines.append(f"> {text}")
        lines.append(f"ID: `{tid}`{' | Category: ' + cat if cat else ''}\n")
    
    return "\n".join(lines)

def wake_openclaw(tweets_for_reply):
    """Send curated tweets to OpenClaw for Bernard to reply to."""
    if not tweets_for_reply:
        return
    
    prompt_parts = [
        "TWITTER LISTENER: High-scoring tweets from accounts I follow.",
        "Even though our account is new and replies may get 403, log these as content inspiration.",
        "For each tweet, decide: reply (if possible), quote-tweet style standalone post, or skip.",
        "Use `bash skills/twitter/reply.sh <tweet_id> \"reply text\"` to attempt replies.",
        "Use `bash skills/twitter/tweet.sh \"text\"` for standalone posts inspired by these.",
        "Space replies 3-40 seconds apart. 280 char limit.",
        "Log any posts to /tmp/twitter-posts-$(date +%Y-%m-%d).log",
        "Skip any you don't have a genuinely good take on.\n"
    ]
    
    for item in tweets_for_reply:
        t = item["tweet"]
        a = item["account"]
        s = item["score"]
        metrics = t.get("public_metrics", {})
        prompt_parts.append(
            f"---\n"
            f"@{a['username']} ({a['category']}, score:{s}) [tweet_id: {t['id']}]\n"
            f"❤️ {metrics.get('like_count',0)} 🔁 {metrics.get('retweet_count',0)} "
            f"💬 {metrics.get('reply_count',0)}\n"
            f"{t['text']}\n"
        )
    
    message = "\n".join(prompt_parts)
    
    if DRY_RUN:
        print("\n=== WOULD SEND TO OPENCLAW ===")
        print(message)
        return
    
    try:
        # Use gateway HTTP chat completions API
        gateway_token = os.environ.get("OPENCLAW_GATEWAY_TOKEN", "")
        if not gateway_token:
            token_line = subprocess.run(
                ["grep", "OPENCLAW_GATEWAY_TOKEN", str(Path.home() / ".openclaw" / ".env")],
                capture_output=True, text=True
            )
            if token_line.stdout.strip():
                gateway_token = token_line.stdout.strip().split("=", 1)[1]
        
        import json as json_mod
        payload = json_mod.dumps({
            "model": "anthropic/claude-sonnet-4-5",
            "messages": [{"role": "user", "content": message}],
            "max_tokens": 4096
        })
        result = subprocess.run(
            ["curl", "-s", "-X", "POST", "http://127.0.0.1:18789/v1/chat/completions",
             "-H", "Content-Type: application/json",
             "-H", f"Authorization: Bearer {gateway_token}",
             "-d", payload],
            capture_output=True, text=True, timeout=180
        )
        if result.returncode == 0 and "choices" in result.stdout:
            print(f"  ✅ Sent {len(tweets_for_reply)} tweets to Bernard")
        else:
            print(f"  ❌ API call failed: {result.stdout[:200]}", file=sys.stderr)
    except Exception as e:
        print(f"  ❌ Failed to wake OpenClaw: {e}", file=sys.stderr)

def main():
    env = load_env()
    bearer_token = env.get("X_BEARER_TOKEN")
    if not bearer_token:
        print("ERROR: X_BEARER_TOKEN not found in .env", file=sys.stderr)
        sys.exit(1)
    
    state = load_state()
    watchlist = load_watchlist()
    
    print(f"[{datetime.now(timezone.utc).isoformat()}] Twitter listener v2 running "
          f"({'DRY RUN' if DRY_RUN else 'DIGEST' if DIGEST_MODE else 'LIVE'}) — {len(watchlist)} accounts")
    
    # Resolve usernames to IDs
    if "user_ids" not in state:
        state["user_ids"] = {}
    
    unresolved = [a["username"] for a in watchlist 
                  if a["username"].lower() not in state["user_ids"]]
    if unresolved:
        print(f"  Resolving {len(unresolved)} usernames...")
        new_ids = resolve_user_ids(unresolved, bearer_token)
        state["user_ids"].update(new_ids)
    
    # Poll ALL accounts (increased from 10)
    candidates = []
    for account in watchlist:
        uname_lower = account["username"].lower()
        uid = state["user_ids"].get(uname_lower)
        if not uid:
            continue
        last_seen = state["last_seen"].get(uname_lower, "0")
        candidates.append((account, uid, last_seen))
    
    candidates.sort(key=lambda x: (
        0 if x[0]["priority"] == "high" else 1 if x[0]["priority"] == "medium" else 2,
        x[2]
    ))
    candidates = candidates[:MAX_ACCOUNTS_PER_RUN]
    
    all_scored = []
    
    for account, uid, _ in candidates:
        uname = account["username"]
        uname_lower = uname.lower()
        since_id = state["last_seen"].get(uname_lower)
        
        data = get_recent_tweets(uid, since_id, bearer_token)
        if not data or "data" not in data:
            continue
        
        tweets = data["data"]
        if not tweets:
            continue
        
        newest_id = max(t["id"] for t in tweets)
        state["last_seen"][uname_lower] = newest_id
        
        for tweet in tweets:
            score = score_tweet(tweet, account)
            if score > 0:
                all_scored.append({
                    "tweet": tweet,
                    "account": account,
                    "score": score
                })
                if score >= 40:
                    print(f"  📝 @{uname}: \"{tweet['text'][:80]}...\" (score: {score})")
    
    all_scored.sort(key=lambda x: x["score"], reverse=True)
    
    # Track daily top tweets for digest
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    if state.get("daily_top_date") != today:
        state["daily_top"] = []
        state["daily_top_date"] = today
    
    for item in all_scored[:10]:
        entry = {
            "username": item["account"]["username"],
            "text": item["tweet"]["text"][:200],
            "score": item["score"],
            "id": item["tweet"]["id"],
            "likes": item["tweet"].get("public_metrics", {}).get("like_count", 0)
        }
        # Deduplicate
        if not any(d["id"] == entry["id"] for d in state["daily_top"]):
            state["daily_top"].append(entry)
    
    # Keep only top 20 per day
    state["daily_top"] = sorted(state["daily_top"], key=lambda x: x["score"], reverse=True)[:20]
    
    # Filter for reply-worthy (score >= 55)
    reply_worthy = [t for t in all_scored if t["score"] >= 55][:MAX_TWEETS_PER_RUN]
    
    if reply_worthy:
        print(f"\n  🎯 {len(reply_worthy)} tweets selected for reply (score ≥55)")
        wake_openclaw(reply_worthy)
    else:
        print(f"  📊 {len(all_scored)} tweets scored, none above reply threshold (55)")
    
    # Generate digest if requested or at end of day (UTC 23:xx)
    if DIGEST_MODE or datetime.now(timezone.utc).hour == 23:
        digest = format_digest(state.get("daily_top", []))
        if digest:
            DIGEST_FILE.write_text(digest)
            print(f"  📰 Daily digest written to {DIGEST_FILE}")
    
    save_state(state)
    print("  Done.")

if __name__ == "__main__":
    main()
