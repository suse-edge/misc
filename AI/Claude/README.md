# 🤖 Claude Team Standards

This directory contains shared Claude Code configuration for the team — skills, hooks, and rules that make Claude behave consistently for everyone, whether you're in engineering, QA, or support.

---

## Why shared configs?

When everyone uses Claude differently, you get inconsistent output, repeated mistakes, and no way to enforce team standards. Shared configs fix that:

- 📏 **Consistency** — Claude follows the same rules and formats for everyone
- 🛡️ **Safety** — hard rules (like never pushing code) are enforced, not just suggested
- ⚡ **Speed** — common workflows become one-liner slash commands
- 🧠 **Shared knowledge** — team conventions live in one place, not in individual heads

---

## What's in here

### 📄 CLAUDE.md

The rules file. Claude reads this automatically and uses it to guide its behavior throughout a session. Think of it as a team handbook for Claude — coding standards, git discipline, safety rules, workflow expectations.

It's **advisory** — Claude will follow it, but it's not enforced at a technical level. Pair it with hooks for anything that must never slip.

👉 See [CLAUDE.md](./CLAUDE.md)

---

### ⚡ Skills

Skills are custom slash commands. You create a markdown file, and the filename becomes the command. Invoke it with `/skill-name` in Claude Code.

They're great for repeated workflows — instead of explaining the same task to Claude every time, you write the instructions once and reuse them forever.

```
/analyze-issue #123   →  structured analysis of a GitHub issue
```

Skills are **project-scoped** — everyone who clones this repo gets them automatically. No setup needed beyond having Claude Code installed.

> 🔌 Some skills require an MCP server (e.g. the GitHub MCP server for issue-related skills). Check the skills README for details.

👉 See [skills/README.md](./skills/README.md)

---

### 🪝 Hooks

Hooks are scripts that run automatically when Claude tries to do something — before or after a tool executes. Unlike CLAUDE.md, hooks are **enforced** — they can block actions outright.

Use them for things that must never happen:

- 🚫 Blocking `git push` (all pushes must come from the user)
- 🌿 Blocking direct commits to `main` or `master`
- 🔑 Detecting secrets before they get written to a file
- 🧹 Running the linter automatically after every file edit

Hooks can be written in **any language** — Python, shell, Rust, Go, etc. Python and shell are preferred for simplicity since they run without a build step. Compiled language hooks (like Rust) require each team member to compile the binary locally. See the hooks README for details.

Hooks are configured in `.claude/settings.json` and live in the `hooks/` directory.

👉 See [hooks/README.md](./hooks/README.md)

---

## How to set everything up

### 1. Install Claude Code

If you haven't already:
```bash
npm install -g @anthropic-ai/claude-code
```

### 2. Clone the repo

Skills and hooks are automatically available once you clone — no extra setup needed for those.

### 3. Compile Rust hooks (if applicable)

Some hooks are written in Rust for teams that already have a Rust toolchain. These need to be compiled once per machine:

```bash
rustc AI/Claude/hooks/block_commit_main.rs -o AI/Claude/hooks/block_commit_main
```

Or if there's a Makefile:
```bash
make hooks
```

Compiled binaries are gitignored — only the `.rs` source files are committed.

### 4. Configure hooks

Copy or reference the hook settings into your project's `.claude/settings.json`. See [hooks/README.md](./hooks/README.md) for the exact JSON.

### 5. Set up MCP servers (if needed)

If you're using skills that interact with GitHub or other external services, you'll need the relevant MCP server configured. See [skills/README.md](./skills/README.md) for details.

### 6. Start using skills

Open Claude Code in your project and type `/` to see available commands.

---

## The golden rule 🏅

> **CLAUDE.md tells Claude what to do. Hooks make sure it actually does it.**

Use CLAUDE.md for conventions and guidance. Use hooks for anything where "Claude forgot" is not an acceptable excuse.

---

## Contributing

Adding a new skill or hook? Great — follow the guidelines in their respective READMEs, keep things focused and simple, and update this README if you're adding something significant.
