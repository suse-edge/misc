import sys
import json

data = json.load(sys.stdin)
command = data.get("tool_input", {}).get("command", "")

if "git push" in command:
    print("Blocked: git push is not allowed from Claude. Push manually.")
    sys.exit(2)

sys.exit(0)
