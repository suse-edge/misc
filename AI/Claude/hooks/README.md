# Hooks

Hooks are scripts that run automatically in response to Claude's actions. They enforce rules that must never be bypassed — unlike CLAUDE.md which is advisory, hooks are deterministic.

## Structure

```
hooks/
├── README.md
├── block_push.py              # Blocks git push attempts (Python)
└── block_commit_main.rs       # Blocks direct commits to main/master (Rust)
```

## How hooks work

Claude pipes a JSON payload to the hook's stdin before (or after) executing a tool. The hook responds with an exit code:

| Exit code | Meaning |
|-----------|---------|
| `0` | Allow — proceed normally |
| `2` | Block — stop the action, show stderr to Claude |

## How to register a hook

Hooks are configured in `.claude/settings.json`. The example below uses `block_push.py` — a hook that prevents Claude from running `git push`:

**`AI/Claude/hooks/block_push.py`:**
```python
import sys
import json

data = json.load(sys.stdin)
command = data.get("tool_input", {}).get("command", "")

if "git push" in command:
    print("Blocked: git push is not allowed from Claude. Push manually.")
    sys.exit(2)

sys.exit(0)
```

**`.claude/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 AI/Claude/hooks/block_push.py"
          }
        ]
      }
    ]
  }
}
```

## Hook events

| Event | Fires |
|-------|-------|
| `PreToolUse` | Before Claude executes a tool — can block |
| `PostToolUse` | After Claude executes a tool — cannot block, used for logging/linting |

---

## Using Rust hooks

Hooks can be written in any language — including Rust. The tradeoff is that compiled hooks require a build step and each team member must compile for their own platform.

### Example — `block_commit_main.rs`

This hook blocks Claude from committing directly to `main` or `master`, enforcing the use of feature branches.

**Compile it:**
```bash
rustc AI/Claude/hooks/block_commit_main.rs -o AI/Claude/hooks/block_commit_main
```

**Register it in `.claude/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "AI/Claude/hooks/block_commit_main"
          }
        ]
      }
    ]
  }
}
```

### Team setup for Rust hooks

Since compiled binaries are platform-specific, follow these steps:

1. **Add binaries to `.gitignore`** — commit the `.rs` source files, not the compiled output:
   ```gitignore
   AI/Claude/hooks/block_commit_main
   ```

2. **Each team member compiles locally** after cloning:
   ```bash
   rustc AI/Claude/hooks/block_commit_main.rs -o AI/Claude/hooks/block_commit_main
   ```

3. **Alternatively, use a Makefile** to automate this:
   ```makefile
   hooks:
       rustc AI/Claude/hooks/block_commit_main.rs -o AI/Claude/hooks/block_commit_main
   ```
   Then team members just run `make hooks` after cloning.

> **Tip:** If the extra build step is a friction point, rewrite the hook in Python instead. Rust hooks make sense when you need performance or already have a Rust toolchain in your workflow.

---

## Guidelines

- Use hooks for hard rules (secrets, destructive commands, force pushes, branch protection)
- Use CLAUDE.md for guidance and conventions — hooks are the backstop
- Prefer Python or shell for hooks — no compilation required, works cross-platform out of the box
- Use Rust (or other compiled languages) only when justified — document the build step clearly
- Keep hooks fast — they run on every matching tool call
- Always handle the case where stdin is empty or malformed
