# Task 0003: Implement Test Package Matrix and Automated Verification Suite

**Opened:** 2026-11-06
**Status:** closed

## What I understand the task to be

Implement an automated test suite executing the 11-test Test Package Matrix (Happy Path, Boundaries, Edge Cases, Negative Cases) for the PLR Verification Program. Each individual test must execute deterministically, validate its specific acceptance criteria, and output an independent, detailed log file recording the inputs, commands run, outputs, assertions, and PASS/FAIL result to `logs/tests/`.

## What I think a usable result includes

1. An automated test suite runner (`tools/run_test_suite.js`) executable directly from the VS Code terminal (`npm test` or `node tools/run_test_suite.js`).
2. Implementations for all 11 test cases:
   - **TC-01**: Happy Path - Fresh initial run (new SIG IDs detected, operator confirmed, times populated, green cells).
   - **TC-02**: Happy Path - Multi-day re-run with existing PLR doc (discovers new satellites, updates existing times without re-prompting).
   - **TC-03**: Boundary - Signal ID rate lower bound (20.0% / 60 tasks).
   - **TC-04**: Boundary - Signal ID rate upper bound (35.0% / 105 tasks).
   - **TC-05**: Boundary - 24-hour midnight time limits (`00:00:00` and `23:59:59`).
   - **TC-06**: Edge Case - Operator declines confirmation (`"n"` -> `"<Operator> - INCOMPLETE"` in red, times updated).
   - **TC-07**: Edge Case - Multiple passes for same satellite in one day (single alert on first SIG ID, times updated to latest pass).
   - **TC-08**: Edge Case - Satellite with zero detections in 24 hours (red box, white confirm box, blank times).
   - **TC-09**: Edge Case - File locked / open in Excel (`EBUSY` graceful fallback to `_updated.xlsx`).
   - **TC-10**: Negative - Invalid / missing file path (graceful error handling, no crash).
   - **TC-11**: Negative - Empty task log (headers only, 0 data rows, handles gracefully).
3. Dedicated log files in `logs/tests/` for each individual test case:
   - `logs/tests/TC-01-happy-path-fresh-run.log`
   - `logs/tests/TC-02-happy-path-multiday-rerun.log`
   - `logs/tests/TC-03-boundary-signal-rate-min.log`
   - `logs/tests/TC-04-boundary-signal-rate-max.log`
   - `logs/tests/TC-05-boundary-time-limits.log`
   - `logs/tests/TC-06-edge-operator-declined.log`
   - `logs/tests/TC-07-edge-multiple-passes-same-sat.log`
   - `logs/tests/TC-08-edge-zero-detections-sat.log`
   - `logs/tests/TC-09-edge-file-lock-ebusy.log`
   - `logs/tests/TC-10-negative-invalid-filepath.log`
   - `logs/tests/TC-11-negative-empty-task-log.log`
   - `logs/tests/test-suite-summary.log`
4. Traceability to Section 5 requirements of `PROJECT_CHECKLIST.md`.

## What I think is out of bounds

- Modifying original accepted results in `output/` during test runs (tests run against isolated scratch files in `work/test_runs/`).
- Hardcoding expected results without programmatically verifying workbook XML and execution outputs.

## What I had to assume

1. Test logs should be stored in `logs/tests/` to keep test evidence organized and cleanly separated.
2. The test suite runner should be runnable via `npm test` or `node tools/run_test_suite.js` directly within the VS Code integrated terminal.
3. Tests create mock task logs on the fly to simulate precise boundary conditions (e.g. exactly 60 signals, midnight timestamps, empty files).

---

**Confirmed by:** User
**Corrections:** None

---

## What happened

1. Developed `tools/run_test_suite.js`, an automated Node.js test harness covering the complete 11-test matrix.
2. Configured test runner commands in `package.json` (`npm test`) and VS Code Task runner (`.vscode/tasks.json`).
3. Implemented synthetic test fixture generation for exact boundary rates (20.0% min, 35.0% max), midnight boundaries (`00:00:00`, `23:59:59`), multi-pass updates, and zero-signal satellites.
4. Integrated true Windows OS file lock simulation in TC-09 using PowerShell `[System.IO.FileShare]::None` to accurately reproduce Excel file lock conditions (`EBUSY`).
5. Added ANSI stripping to test log assertions to guarantee robust terminal string verification across all environments.
6. Executed the automated test suite with 100% pass rate (11 of 11 tests passing).
7. Verified all 11 individual test log files and the master summary report were cleanly generated in `logs/tests/`.

## Outcome

**Ship**

## Why

- **Defensibility:** Every test assertion is directly tied to specific acceptance criteria from `PROJECT_CHECKLIST.md` (Section 5), covering happy path, boundary conditions, edge cases, and negative fault handling.
- **Verification Evidence:** All 11 tests pass with complete log evidence stored in `logs/tests/`, including timestamps, exact command lines executed, full CLI transcript, assertion statuses, and exit codes.
- **Repeatability:** Test suite is completely isolated in `work/test_runs/`, non-destructive to `output/`, and callable on demand via `npm test` or VS Code Tasks.

## Decision Record

- **Decided:** To write dedicated mock task logs on the fly rather than checking in large static test fixtures.
  - *Alternative:* Storing 11 separate static `.xlsx` fixture files in a `test_data/` folder.
  - *Why the alternative lost:* Generating synthetic logs in-memory ensures precise boundary control (e.g., exactly 60 positive signals out of 300, or exact timestamp bounds) without cluttering repository storage.
- **Decided:** To implement a dedicated logger class writing separate `.log` files per test ID (`TC-XX-*.log`) alongside a master summary log (`test-suite-summary.log`).
  - *Alternative:* A single monolithic test log containing all outputs.
  - *Why the alternative lost:* Separate logs allow direct linking and review of specific acceptance criteria evidence required for project verification audits.
