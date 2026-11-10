# AGENTS.md

Global instructions for coding agents. A repo-local `AGENTS.md` or `PLAN.md` overrides this file. Product behavior lives in the plan; this file is taste and brakes.

## Stack

- Prefer Ruby and Rails 8. The human writes Rails for web systems and POROs / `lib/` for domain.
- Docker Compose for anything that runs more than one process. Bind-mount code; keep durable state in a named volume or `./data`.
- UI: Hotwire, Turbo, Stimulus. Do not add React, Vue, Next, or an SPA unless asked.
- Database: PostgreSQL + Active Record **when the project needs a database**. Do not add a DB to a file- or memory-backed app just because Rails can.
- Jobs: Solid Queue. Cache/cable: Solid Cache / Solid Cable. Do not add Redis, Sidekiq, or another broker unless asked.
- Concurrent I/O: `async` (or whatever the repo already uses). Do not open long-lived sockets from Puma request threads.

## Desk live

The application layout owns the live stream, the pulse, and the disconnect warning. Do not add a page-local copy. The warning keeps pulsing and reloads the page when the server answers.

New records the desk can see implement `#venue` (usually `belongs_to :venue`). `ApplicationRecord` touches that venue so every open page remorphs. Call `skip_venue_desk!` only for auth rows or high-frequency log lines that have their own stream.

## Rails way

- Convention over configuration. Default generators, default paths, default layout.
- Skinny controllers. Domain in models and POROs. No `app/services/`, `app/interactors/`, or `app/use_cases/` unless the human asked for that pattern.
- One application. Split a gem or a second service only when there is a second consumer.
- Config via Rails credentials, ENV, and YAML the usual way. No custom config DSL.

## Metz / DHH taste

- Small objects, one job each. Composition over inheritance.
- Tell, don’t ask. Depend on roles, not on brands or `if type ==`.
- **Duplication is cheaper than the wrong abstraction.** DRY is for knowledge, not keystrokes.
  - Extract when the same *rule* appears twice.
  - Do not invent a PluginRegistry, BaseService, or framework after one example.
  - The third similar object is when you extract a tiny helper — not before.
- No god objects. No metaprogramming to avoid a `case`.
- Prefer deleting code to wrapping it.

## Tests

- **Minitest.** `bin/rails test`, files under `test/`. Domain POROs in `test/lib` or next to the object. Request/system tests the Rails way.
- Do not add RSpec, `spec/`, or rspec-rails unless the human explicitly switches.
- If a repo already has `spec/` and no `test/`, match that repo rather than converting it unasked.
- Every behavior change ships with a test in the same turn. Do not skip or delete a failing test to go green.
- Prefer fakes and fixtures over live network or third-party APIs.
- Cover domain branches. Do not chase 100% on views or bin wrappers.
- Fixtures or plain objects over FactoryBot. If the project already uses FactoryBot, keep using it.

```
bin/rails test
```

## Comments

Comment *why* and *protocol*, not *what*.

Write:

- Wire formats, vendor quirks, timing, safety.
- Non-obvious invariants on public domain methods.
- A one-line intent on a public method when the name is not enough.

Do not write:

- Comments that restate the next line.
- Commented-out code.
- File-level essays that duplicate `PLAN.md`.

## How to take work

1. Read this file, then any repo `AGENTS.md` / `PLAN.md`.
2. Do **one** asked task. If the human named a spike or PR scope, stop at the end of it.
3. Do not start the next layer unasked (no extra gem, no extra process, no extra UI chrome).
4. End the turn with: what changed, how to run it, what you guessed, what you did not touch.

## Do not

- Add Node, Go, Python, or a second language because it is fashionable.
- Add PostgreSQL to an app that was specified as files-on-disk.
- Add Redis, Kafka, Elasticsearch, or a mesh.
- Add Devise / OAuth / a user table when the human asked for a PIN or no auth.
- Rescue `StandardError` around I/O. Rescue the specific error, log it, keep going if that is the policy.
- Invent folders the project does not use.
- Commit secrets. `.env` and credentials stay local.

## Style

- RuboCop Rails Omakase if the app has it. Do not litter `rubocop:disable` unless the parser is unreadable otherwise.
- Keyword args on constructors. Value objects (`Data.define` or frozen structs) for events and commands.
- `1.5.seconds` in domain code; raw protocol units only at the adapter edge.
