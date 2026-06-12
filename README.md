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

Credits
- This Haskell port preserves the design and intent of the original `autofhir` project. The upstream original project is available at:

  https://github.com/jmandel/autofhir

- Original project author: Jared Mandel (@jmandel). This port reimplements the orchestration ideas from that repository in Haskell for an MVP while preserving the on-disk layout and worker lifecycle semantics.

License
- This port is released under the MIT License. See `LICENSE`.

