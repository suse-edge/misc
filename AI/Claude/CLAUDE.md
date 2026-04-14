# Claude Team Standards

This file defines shared rules for Claude across the team. All rules here apply to everyone — engineering, QA, and support.

## Safety

- Never run `git push` — all pushes must be done manually by the user
- Never commit secrets, API keys, or tokens — use environment variables
- Never bypass pre-commit hooks with `--no-verify`
- Never force push to `main`

## Code quality

- Always run tests before considering a task done
- Always run the linter after editing code
- Don't add features, refactoring, or improvements beyond what was asked

## Git discipline

- Write clear, descriptive commit messages
- One logical change per commit
- Branch names must describe the work (e.g. `feature/x`, `fix/y`, `chore/z`)

## Communication

- If a task is ambiguous, ask before starting — don't assume
- When blocked, state why clearly instead of guessing a workaround

## Workflow

- Use `/analyze-issue` before picking up any GitHub issue
- Read existing code before writing new code — don't duplicate logic
