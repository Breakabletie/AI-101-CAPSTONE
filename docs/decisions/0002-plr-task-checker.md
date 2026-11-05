# Task 0002: Post-Launch Requirements (PLR) Task Log Verification Program

**Opened:** 2026-11-06
**Status:** closed

## What I understand the task to be

Build a deterministic CLI program that accepts two inputs:
1. A user-selected satellite mission task log (e.g. `output/2026-11-06.xlsx`).
2. A `post_launch_requirements.xlsx` tracking document (auto-created if it does not exist).

The program loads PLR state into memory, scans the task log, and when a satellite's first Signal ID is detected, alerts the operator in the terminal and prompts them to confirm that subsequent mission requirements have been completed. It then writes the PLR document with color-coded status cells and operator accountability.

## What I think a usable result includes

1. A runnable PowerShell script (`tools/check_plr_tasks.ps1`) that interactively prompts for the task log path and operator name if not supplied as parameters.
2. Auto-creation of `post_launch_requirements.xlsx` if it does not exist; loading and updating it if it does.
3. PLR Document columns: SSC, Satellite Name, SPUT, SIG ID (colored box), Operator Confirm Next Requirement Completed (colored box), Start time, End time.
4. Color-coded cell styling per specification.
5. Terminal alerts for each newly discovered SIG ID with full task details and operator confirmation prompts.

## What I think is out of bounds

- Modifying the input satellite task log files.
- Auto-completing subsequent requirements without operator confirmation.
- Generating a GUI.

## What I had to assume

1. The PLR document includes a `Satellite Name` column for operator readability alongside SSC.
2. Operator is prompted for their name at program launch.
3. Subsequent SIG ID encounters for an already-achieved satellite update start/stop times silently without re-alerting.

## Sources I expect to need

- `output/2026-11-06.xlsx` (generated dummy task log from Task 0001).
- `PROJECT_CHECKLIST.md` (specifications and constraints for the PLR feature).

---

**Confirmed by:** User (three submissions confirming requirements)
**Corrections:** None required beyond initial spec.

---

## What happened

1. Authored `tools/check_plr_tasks.ps1` using native .NET OpenXML generation (no external dependencies).
2. Implemented mutable hashtable-based in-memory PLR records to support property updates during processing.
3. Implemented full color-coded Excel styling:
   - SIG ID box: RED (default, no signal) / GREEN (achieved, shows operator name).
   - Confirm box: WHITE (not applicable) / RED (pending confirmation) / GREEN (confirmed completed).
   - Start/End times: blank until SIG ID found, then updated to most recent pass.
4. Terminal alerts display full task details (Task Number, Satellite Name, SSC, SPUT, Signal ID, Start/Stop times) for each first-time SIG ID discovery.
5. Tested Day 1 fresh run: 18 new achievements detected out of 20 satellites, 42 subsequent pass updates, all confirmed.
6. Tested Day 2 re-run against existing PLR document: loaded 20 records, detected exactly 2 remaining new achievements (SIMSAT-05, SIMSAT-15), recorded as PENDING when operator declined confirmation, updated 78 subsequent pass times.
7. Verified output document: all 20 satellites GREEN SIG ID after Day 2, 18 GREEN confirmations + 2 RED pending, times correctly present on all 20 and blank on none.

8. Added interactive task log picker in `tools/check_plr_tasks.js` and `tools/check_plr_tasks.ps1` that scans the output directory, displays all available satellite task logs (sorted latest first), and allows selection by index number (defaulting to latest) or custom path input.
9. Updated PLR spreadsheet cell formatting per user refinement:
   - `SIG ID` column: solid green or red colored box with no text.
   - `Operator Confirm Next Requirement Completed` column: stamped with `<OPERATOR> - CONFIRMED COMPLETED` (green) or `<OPERATOR> - INCOMPLETE` (red).

## Outcome

**Ship**

## Why

All requirements met and verified across multiple test scenarios. The program correctly handles both fresh creation and re-run update workflows, preserves operator accountability, and implements all specified color-coding logic.
