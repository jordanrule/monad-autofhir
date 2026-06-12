Design decisions preserved from the original `autofhir` project

This file documents the core design choices that the Haskell MVP preserves.

1. On-disk run model
   - Each run is represented on disk (e.g. `runs/<run-id>`).
   - Work items (chunks) are stored as JSON files under `chunks/pending` initially.
   - Workers move chunk files through `chunks/running` and finally to `chunks/done` to indicate progress.
   - Results are also written to a `results/` directory for easy inspection.

2. Journaling
   - Important events (chunk started, chunk done, errors) are appended to `journal/journal.ndjson` as NDJSON entries.
   - Entries are simple JSON objects with a timestamp, type, and payload.

3. Immutable state and effectful boundaries
   - Configuration and environment are represented by an immutable `AppEnv` passed via a Reader monad (`AppM` = ReaderT AppEnv IO).
   - Pure logic (data transformations) should be kept separate from effectful code (FS, process invocation) to ease reasoning and testing.

4. Worker lifecycle and external tools
   - Workers are implemented as lightweight asynchronous tasks (Haskell `async`) consuming a shared STM queue (TBQueue).
   - Each worker writes a prompt file, calls the external `copilot` binary, decodes the result if JSON, and writes the result file and journal entry.

5. Simplicity for MVP
   - The monad stack is intentionally minimal (ReaderT over IO) rather than a larger effects system. This keeps the port approachable and easy to expand.

6. Interop and file formats
   - JSON shapes for chunk files and journal entries are preserved to allow interoperability with existing run directories and tooling.

Extending the MVP
- To reach full parity with the original project, add modules for:
  - Git/worktree orchestration (commit/publish flow and Finding-ID commit trailers).
  - DB access for prepare scripts (sqlite-simple wrappers).
  - Full CLI parity for all original helper scripts (init-run, prepare-*, monitor, recover).
  - Structured logging and tests.

