# monad-autofhir


Haskell MVP port of the `autofhir` orchestration tools.

This repository contains a minimal, opinionated Haskell reimplementation of the core orchestration from the original `autofhir` project. The goal for this MVP is to preserve intent and the important design decisions while keeping the implementation small and testable. State is represented immutably via a Reader-based monad (`AppM`), and side effects (filesystem, processes) are executed at the edges.

Quick start (requires Stack):

```bash
cd /Users/jrule/git/fhir/monad-autofhir
stack build
stack exec monad-autofhir -- --help
```

Install Stack (macOS Homebrew example):

```bash
brew install haskell-stack
```

Quick local test (creates a small run directory and one dummy chunk)

```bash
cd /Users/jrule/git/fhir/monad-autofhir
# create a demo run directory
mkdir -p demo-run/chunks/pending
# write a simple chunk JSON file
cat > demo-run/chunks/pending/chunk-1.json <<'JSON'
{
  "chunkId": "chunk-1",
  "payload": { "task": "echo hello" }
}
JSON

# run the coordinator (use --copilot pointing to a simple script that echoes JSON)
# create a trivial copilot stub that echoes the chunk
cat > /tmp/copilot-stub.sh <<'SH'
#!/usr/bin/env bash
cat "$1"
SH
chmod +x /tmp/copilot-stub.sh

# build and run (requires stack)
stack build
stack exec monad-autofhir -- --run demo-run --concurrency 1 --copilot /tmp/copilot-stub.sh
```

What this MVP implements
- Coordinator loop that polls `chunks/pending` and processes chunk JSON files with a worker pool.
- Chunk lifecycle: pending -> running -> done (files moved between directories to represent state transitions).
- Journaling: append NDJSON entries to `journal/journal.ndjson` for important events.
- Worker integration: invokes an external `copilot` binary on a prompt file and stores the result.
- Immutable configuration: `AppEnv` (envRoot, envRunId, envCopilot) is injected via `AppM` (ReaderT).

Project layout
- `app/Main.hs` — small CLI to run the coordinator.
- `src/Autofhir/*` — core library modules (Types, Env, FS, Proc, Coordinator).
- `LICENSE` — MIT license for this port.

Design and intent
- The on-disk run model from the original project is preserved: run directories contain `chunks/{pending,running,done}`, `results/` and `journal/`.
- Idempotency and visibility are expressed via file moves and journal entries rather than in-memory mutable state.
- The monad stack is intentionally simple (ReaderT over IO) to keep the design transparent and easily testable.

Typed Events and safer journaling
- Motivation: the system records important lifecycle and result information to a journal (NDJSON). Historically, journal entries may be emitted as loosely structured JSON objects. Moving to a single, well-typed `Event` algebraic data type improves safety, clarity, and maintainability.
- What "typed Event" means: define an explicit `Event` type in Haskell that enumerates the kinds of events the system emits. Each constructor captures the required fields for that event, and the type derives (or has custom) `ToJSON`/`FromJSON` instances for persisted NDJSON.
- Example (illustrative):

```haskell
-- src/Autofhir/Types.hs (example)
data Event
  = EventChunkQueued { eChunkId :: Text, eTimestamp :: UTCTime }
  | EventChunkStarted { eChunkId :: Text, eWorkerId :: Text, eTimestamp :: UTCTime }
  | EventChunkSucceeded { eChunkId :: Text, eResult :: Value, eTimestamp :: UTCTime }
  | EventChunkFailed { eChunkId :: Text, eError :: Text, eTimestamp :: UTCTime }
  deriving (Show, Eq, Generic)

instance ToJSON Event where
  -- derive or implement a stable JSON shape, e.g. include a "kind" field and payload
```

- How it maps to journaling: each in-memory `Event` value is serialized to a single JSON object and appended (one-per-line) to `journal/journal.ndjson`. When reading the journal, parse each line into `Event` and then handle it deterministically.
- Safety improvements:
  - Compile-time guarantees: the shape and required fields of each event are encoded in the type system, reducing runtime decoding/shape errors.
  - Explicit event kinds: it's harder to accidentally emit inconsistent or malformed journal entries.
  - Easier refactoring: adding/removing event kinds forces you to handle those changes at compilation time.
  - Simpler validation: validation of event payloads happens when constructing the typed `Event` rather than during ad-hoc JSON assembly.
  - Better replayability and audits: typed events make it safer to replay journal entries, implement idempotent reconstructions, or use the journal as an event-sourced state if desired in the future.
  - Clear upgrade/migration path: versioning strategies (e.g. `EventV1`, `EventV2`, or explicit "version" fields) can be applied systematically.

- Operational notes:
  - Keep the serialized JSON shape stable: prefer a top-level `kind` or `type` field plus a `payload` object. Document the schema for tool interoperability.
  - When reading historical journal entries, fail fast and log errors rather than silently ignoring malformed lines.
  - Tests: add property tests that round-trip `Event -> JSON -> Event` and unit tests for event-based transitions.

Credits
- This Haskell port preserves the design and intent of the original `autofhir` project. The upstream original project is available at:

  https://github.com/jmandel/autofhir

License
- This port is released under the MIT License. See `LICENSE`.

