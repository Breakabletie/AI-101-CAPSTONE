# tools/

Checks that run, rather than rules people remember.

**A rule in `AGENTS.md` is a reminder. A rule in a script is a check.** The difference shows
up on the day somebody is in a hurry.

| Tool | What it does |
|---|---|
| `check-output.sh` | Scans a file for things that should not have survived sanitization (Bash) |
| `check-output.ps1` | Scans a file for things that should not have survived sanitization (PowerShell) |
| `generate_satellite_tasks.ps1` | Generates 300 chronological dummy satellite tasks in an Excel file (`output/YYYY-MM-DD.xlsx`). Advances date and adds new unique satellites on repeated runs. |
| `check_plr_tasks.js` | PLR Verification Program for **VS Code Integrated Terminal** (Node.js). Compares a task log against `post_launch_requirements.xlsx`, alerts on new SIG IDs, prompts operator, and writes color-coded spreadsheet. |
| `check_plr_tasks.ps1` | PLR Verification Program (PowerShell version). |

Run sanitization check before anything leaves `work/`:

```
tools/check-output.sh work/yourfile.md
# Or in PowerShell:
powershell -ExecutionPolicy Bypass -File tools/check-output.ps1 tasks/yourfile.md
```

## Running in Visual Studio Code

Open your VS Code terminal (`Ctrl+\`` or `Terminal -> New Terminal`) and run:

```bash
# Direct node execution:
node tools/check_plr_tasks.js

# Or via npm:
npm start

# Or via VS Code Tasks:
# Press Ctrl+Shift+B (or Terminal -> Run Task... -> Run PLR Verification Program)
```

## Adding to it

Good candidates are whatever people skip when rushed. Checking that every file in `sources/`
has a row in `SOURCES.md`. Verifying nothing in `output/` is newer than its task file.
Scanning for your organization's own identifier formats, which this script does not know.

Keep them fast and boring. A check that takes a minute gets run. One that takes ten does not.
