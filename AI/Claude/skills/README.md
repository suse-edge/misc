# Skills

Skills are custom slash commands that extend Claude's behavior for repeated workflows. Each skill is a markdown file — the filename becomes the command name.

## Structure

```
skills/
├── README.md
└── analyze-issue.md    →  /analyze-issue
```

## How to create a skill

Create a markdown file describing what Claude should do. Use `$ARGUMENTS` to capture anything typed after the command name.

**Example — `skills/analyze-issue.md`:**
```markdown
Analyze the GitHub issue provided in $ARGUMENTS (issue number or URL).

1. **Type** — classify as: Bug, Feature Request, Improvement, or Question
2. **Summary** — one sentence describing the core problem or request
3. **Impact** — who is affected and how severely (P1/P2/P3)
4. **Affected area** — which part of the codebase or system is likely involved
5. **Next steps** — what is needed to start working on this

...
```

Invoke it with: `/analyze-issue #123` or `/analyze-issue https://github.com/org/repo/issues/123`

## How to use skills

Type `/skill-name` in Claude Code. If the skill accepts arguments, add them after the command name.

## MCP server requirement

Some skills interact with external services like GitHub. For these to work, the relevant **MCP (Model Context Protocol) server** must be configured.

For `analyze-issue` and any other GitHub-related skills, the GitHub MCP server must be set up in `.mcp.json`:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "<your token>"
      }
    }
  }
}
```

> Keep your token out of version control. Use environment variables or a secrets manager. Add `.mcp.json` to `.gitignore` if it contains sensitive values, or use a `.mcp.local.json` for personal credentials.

## Scope

- Skills in this directory are **project-scoped** — available to everyone who clones this repo.
- Personal skills go in `~/.claude/commands/` and are not shared with the team.

## Guidelines

- One skill per file, one clear purpose
- Name the file after what it does (`analyze-issue.md`, not `issue.md`)
- Keep prompts concise — Claude reads the whole file as a system instruction
- Use `$ARGUMENTS` when the skill needs user input
- Document any external dependencies (MCP servers, environment variables) in this README
