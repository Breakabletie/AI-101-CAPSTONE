# Decision 0001: Satellite task log generator architecture and schema

**Date:** 2026-11-06
**Status:** active

## What was decided

1. **Native OpenXML generation**: Implemented a standalone PowerShell generation utility (`tools/generate_satellite_tasks.ps1`) using .NET's native `System.IO.Compression.ZipArchive` to build valid OpenXML `.xlsx` spreadsheets directly without third-party package dependencies (e.g. npm exceljs or Python pandas/openpyxl).
2. **Persistent state tracking**: Implemented JSON-based state tracking (`tools/satellite_state.json`) to remember the latest date, known satellite fleet, and signal sequence counters across executions.
3. **Multi-day evolution**: Each run automatically increments the filename to the next calendar day (`YYYY-MM-DD.xlsx`) and injects a random number (1 to 4) of new unique simulated satellites (with unique 5-digit SSCs) into the task list, ensuring every new satellite is guaranteed to appear in that day's log to test the PLR program's satellite detection logic.
4. **Field specifications**:
   - `Task Number`: Integer 1 to 300.
   - `Satellite Name`: Formatted `SIMSAT-NN` (20 in Day 1, growing incrementally).
   - `SSC`: 5-digit integer uniquely tied to the satellite name (starting at 51001).
   - `SPUT`: 4-digit integer (1000..9999).
   - `Signal ID`: Alphanumeric identifier (`SIG-NNNN`) for 20% to 35% of tasks; default `"neg"` for all remaining rows.
   - `Start time` & `Stop time`: Strict `HH:MM:SS` format within the 24-hour day, with overlapping task run times permitted. Chronologically ordered by Start time.

## What else was considered

- **Requiring npm/python packages (e.g. exceljs or openpyxl)**: Rejected because adding external runtime dependencies introduces environment failure modes and requires unsandboxed package installations on Windows. The native .NET OpenXML zip generator runs out-of-the-box in any standard Windows shell without network access.
- **Stateless script with manual date arguments**: Rejected because the user requires automated next-day progression and incremental introduction of new satellites on repeated runs to simulate operational multi-day shifts for the capstone PLR program.
- **Full ISO datetime strings (`YYYY-MM-DD HH:MM:SS`)**: Considered in initial draft, but rejected upon user clarification that start and stop times must be strictly `HH:MM:SS` as the date is already represented by the filename.

## What this rests on

- `PROJECT_CHECKLIST.md` Constraint 1: "The logs and PLR document data will be in excel documents".
- User operational constraints: 20–35% Signal ID rate, 20 initial satellites, 300 tasks, overlapping run times allowed.
- Native Windows .NET Framework 4.5+ / PowerShell 5.1+ availability.

## What would make us revisit

- If the downstream PLR program requires CSV/JSON input format instead of Excel `.xlsx`.
- If real Space Surveillance Catalog (SSC) ranges or specific operational SPUT code mappings are provided.
