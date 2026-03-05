#!/usr/bin/env python3
"""
Add a task to the Bernard task queue.

Usage:
  python3 tasks/add.py script "bash scripts/foo.sh" --priority 1
  python3 tasks/add.py notify "Hey G, something happened" --target <TELEGRAM_CHAT_ID>
  python3 tasks/add.py check "python3 scripts/check-something.py" --priority 2
  python3 tasks/add.py script "bash scripts/foo.sh" --run-after "2026-03-06T08:00:00+00:00"
"""

import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

QUEUE_FILE = Path(__file__).parent / "queue.json"


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 tasks/add.py <type> <command|message> [--priority N] [--target ID] [--run-after ISO] [--max-retries N]")
        sys.exit(1)

    task_type = sys.argv[1]
    content = sys.argv[2]

    # Parse optional args
    args = sys.argv[3:]
    priority = 5
    target = "<TELEGRAM_CHAT_ID>"
    run_after = ""
    max_retries = 3

    i = 0
    while i < len(args):
        if args[i] == "--priority" and i + 1 < len(args):
            priority = int(args[i + 1]); i += 2
        elif args[i] == "--target" and i + 1 < len(args):
            target = args[i + 1]; i += 2
        elif args[i] == "--run-after" and i + 1 < len(args):
            run_after = args[i + 1]; i += 2
        elif args[i] == "--max-retries" and i + 1 < len(args):
            max_retries = int(args[i + 1]); i += 2
        else:
            i += 1

    task = {
        "id": str(uuid.uuid4())[:8],
        "type": task_type,
        "priority": priority,
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "run_after": run_after,
        "max_retries": max_retries,
        "retries": 0,
        "last_error": "",
        "completed_at": "",
        "target": target,
    }

    if task_type == "notify":
        task["message"] = content
    else:
        task["command"] = content

    # Load and append
    if QUEUE_FILE.exists():
        with open(QUEUE_FILE) as f:
            data = json.load(f)
    else:
        data = {"version": 1, "tasks": []}

    data["tasks"].append(task)

    with open(QUEUE_FILE, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Added task {task['id']} ({task_type}, priority {priority})")


if __name__ == "__main__":
    main()
