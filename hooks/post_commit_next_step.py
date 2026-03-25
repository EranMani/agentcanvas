"""Post-commit next step explanation hook.

Fires after every Bash tool call. If the command was a git commit,
injects an instruction for Claude to automatically explain what the
next protocol step will build — without the user having to ask.
"""

import json
import sys


def main() -> None:
    data = json.load(sys.stdin)
    command: str = data.get("tool_input", {}).get("command", "")

    if "git commit" not in command:
        sys.exit(0)

    message = (
        "Commit successful. "
        "Read commit-protocol.md to identify the next step. "
        "Then read AGENTS.md to check whether this step requires a prerequisite handoff "
        "from another agent before work can begin. "
        "Determine which team member owns that step (Claude, Aria, Rex, or Nova). "
        "Concisely explain: what you will build, which agent will do it, and whether any "
        "cross-agent coordination is needed first — "
        "then ask Eran for permission to proceed."
    )

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": message,
        }
    }))


if __name__ == "__main__":
    main()
