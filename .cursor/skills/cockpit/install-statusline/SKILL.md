---
name: install-statusline
description: Configure the Cursor CLI status line to use the cockpit instrument register. Use after installing or updating the cockpit port, or when the user says "set up the cockpit statusline".
disable-model-invocation: true
---

Run exactly this, with one Bash call, and print its output:

```bash
bash ".cursor/cockpit/scripts/install-statusline.sh"
```

Do not edit `~/.cursor/cli-config.json` by hand — the script backs it up and writes the one key.
