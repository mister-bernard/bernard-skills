#!/bin/bash
# SAM.gov procurement scanner — runs daily, notifies G if anything found
# Pure script, zero LLM tokens

set -e
cd ~/.openclaw/workspace

output=$(python3 projects/procurement-scanner/scripts/scan.py 2>&1)
exit_code=$?

# Check results
relevant=$(echo "$output" | grep "Relevant matches:" | grep -oP '\d+')

if [ "$exit_code" -ne 0 ]; then
    echo "Scanner failed: $output"
    exit 1
fi

if [ -z "$relevant" ] || [ "$relevant" -eq 0 ]; then
    echo "No relevant opportunities found"
    exit 0
fi

# Format notification for G
count=$(python3 -c "
import json
data = json.load(open('projects/procurement-scanner/data/latest-results.json'))
opps = data['opportunities'][:5]
lines = [f'🔍 SAM.gov: {len(data[\"opportunities\"])} aviation/IT opportunities found\n']
for o in opps:
    lines.append(f'📋 {o[\"title\"][:60]}')
    lines.append(f'   {o[\"agency\"][:40]} | Deadline: {o[\"responseDeadline\"]}')
    lines.append('')
if len(data['opportunities']) > 5:
    lines.append(f'... and {len(data[\"opportunities\"]) - 5} more')
print('\n'.join(lines))
")

# Add to task queue as a notification
python3 tasks/add.py notify "$count" --priority 3
echo "Queued notification with $relevant opportunities"
