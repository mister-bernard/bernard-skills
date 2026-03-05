#!/usr/bin/env python3
"""
Bernard Task Queue Worker
Run by cron every 30min. Pure Python, zero LLM tokens.

Task format in queue.json:
{
  "id": "uuid",
  "type": "script|notify|check",
  "command": "bash scripts/foo.sh",       # for type=script
  "message": "text to send",              # for type=notify
  "target": "<TELEGRAM_CHAT_ID>",                   # telegram chat id for notify
  "priority": 1,                          # lower = higher priority
  "status": "pending|running|done|failed",
  "created_at": "ISO timestamp",
  "run_after": "ISO timestamp",           # optional: don't run before this time
  "max_retries": 3,
  "retries": 0,
  "last_error": "",
  "completed_at": ""
}
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

WORKSPACE = Path(os.path.expanduser("~/.openclaw/workspace"))
QUEUE_FILE = WORKSPACE / "tasks" / "queue.json"
LOG_FILE = Path("/tmp/bernard-worker.log")
MAX_TASK_AGE_DAYS = 7  # auto-clean completed tasks older than this


def log(msg):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def load_queue():
    if not QUEUE_FILE.exists():
        return {"version": 1, "tasks": []}
    with open(QUEUE_FILE) as f:
        return json.load(f)


def save_queue(data):
    with open(QUEUE_FILE, "w") as f:
        json.dump(data, f, indent=2)


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def is_ready(task):
    """Check if a task is ready to run."""
    if task["status"] != "pending":
        return False
    if "run_after" in task and task["run_after"]:
        run_after = datetime.fromisoformat(task["run_after"].replace("Z", "+00:00"))
        if datetime.now(timezone.utc) < run_after:
            return False
    return True


def run_script_task(task):
    """Execute a script task."""
    cmd = task.get("command", "")
    if not cmd:
        return False, "No command specified"

    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            timeout=300, cwd=str(WORKSPACE)
        )
        if result.returncode == 0:
            return True, result.stdout[:500]
        else:
            return False, f"Exit {result.returncode}: {result.stderr[:300]}"
    except subprocess.TimeoutExpired:
        return False, "Timeout after 300s"
    except Exception as e:
        return False, str(e)[:300]


def run_notify_task(task):
    """Send a notification via openclaw gateway."""
    message = task.get("message", "")
    target = task.get("target", "<TELEGRAM_CHAT_ID>")  # default to G
    channel = task.get("channel", "telegram")

    if not message:
        return False, "No message specified"

    try:
        # Use the message CLI or curl the gateway
        result = subprocess.run(
            ["openclaw", "message", "send", "--channel", channel,
             "--to", str(target), "--message", message],
            capture_output=True, text=True, timeout=30,
            cwd=str(WORKSPACE)
        )
        if result.returncode == 0:
            return True, "Sent"
        else:
            return False, result.stderr[:200]
    except Exception as e:
        return False, str(e)[:200]


def run_check_task(task):
    """Run a check command and notify if output is non-empty."""
    cmd = task.get("command", "")
    if not cmd:
        return False, "No command"

    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            timeout=120, cwd=str(WORKSPACE)
        )
        output = result.stdout.strip()
        if output:
            # Something found — notify
            target = task.get("target", "<TELEGRAM_CHAT_ID>")
            channel = task.get("channel", "telegram")
            subprocess.run(
                ["openclaw", "message", "send", "--channel", channel,
                 "--to", str(target), "--message", output[:4000]],
                capture_output=True, text=True, timeout=30,
                cwd=str(WORKSPACE)
            )
            return True, f"Check found results, notified. Output: {output[:200]}"
        else:
            return True, "Check clean — nothing to report"
    except Exception as e:
        return False, str(e)[:200]


def cleanup_old_tasks(data):
    """Remove completed/failed tasks older than MAX_TASK_AGE_DAYS."""
    cutoff = datetime.now(timezone.utc).timestamp() - (MAX_TASK_AGE_DAYS * 86400)
    original_count = len(data["tasks"])
    data["tasks"] = [
        t for t in data["tasks"]
        if t["status"] in ("pending", "running") or
        (t.get("completed_at") and
         datetime.fromisoformat(t["completed_at"].replace("Z", "+00:00")).timestamp() > cutoff)
    ]
    removed = original_count - len(data["tasks"])
    if removed:
        log(f"Cleaned {removed} old tasks")


def main():
    data = load_queue()
    tasks = data.get("tasks", [])

    if not tasks:
        # Nothing to do — exit silently (no log spam)
        return

    # Sort by priority (lower = higher)
    ready = [t for t in tasks if is_ready(t)]
    ready.sort(key=lambda t: t.get("priority", 5))

    if not ready:
        log(f"Queue has {len(tasks)} tasks, none ready")
        return

    log(f"Processing {len(ready)} ready tasks out of {len(tasks)} total")

    for task in ready:
        task_type = task.get("type", "script")
        task_id = task.get("id", "?")
        log(f"Running task {task_id} ({task_type}): {task.get('command', task.get('message', ''))[:60]}")

        task["status"] = "running"
        save_queue(data)

        handlers = {
            "script": run_script_task,
            "notify": run_notify_task,
            "check": run_check_task,
        }

        handler = handlers.get(task_type, run_script_task)
        success, output = handler(task)

        if success:
            task["status"] = "done"
            task["completed_at"] = now_iso()
            task["last_error"] = ""
            log(f"Task {task_id} completed: {output[:100]}")
        else:
            task["retries"] = task.get("retries", 0) + 1
            max_retries = task.get("max_retries", 3)
            if task["retries"] >= max_retries:
                task["status"] = "failed"
                task["completed_at"] = now_iso()
                log(f"Task {task_id} FAILED permanently: {output[:100]}")
            else:
                task["status"] = "pending"
                log(f"Task {task_id} failed (retry {task['retries']}/{max_retries}): {output[:100]}")
            task["last_error"] = output

    cleanup_old_tasks(data)
    save_queue(data)
    log("Worker run complete")


if __name__ == "__main__":
    main()
