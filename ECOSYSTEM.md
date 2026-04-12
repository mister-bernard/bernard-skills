# Ecosystem

This repo is part of the [Bernard Bootstrap](https://github.com/mister-bernard/bernard-bootstrap) ecosystem.

## Role
Skill packages — 12 self-contained skill directories with docs and scripts. Voice, steganography, Twitter, SMS, music generation, Telegram groups, and more.

## Related repos
| Repo | Role |
|------|------|
| [bernard-bootstrap](https://github.com/mister-bernard/bernard-bootstrap) | Master entry point — templates, playbooks, provisioning |
| [openclaw-claude-bridge](https://github.com/mister-bernard/openclaw-claude-bridge) | `cc` command, CLAUDE.md synth, tmux launcher |
| **cc-bridge** (private) | Persistent CC sessions as OpenAI-compatible HTTP endpoint |
| **openclaw-1** (private) | Modified OpenClaw fork |

## Setup
To clone all ecosystem repos at once:
```
git clone https://github.com/mister-bernard/bernard-bootstrap.git
cd bernard-bootstrap
bash setup-ecosystem.sh
```
