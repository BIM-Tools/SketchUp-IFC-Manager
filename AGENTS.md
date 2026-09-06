# AGENTS.md

Contract for anyone, human or agent, changing this repository. Kept short on purpose: rules live
in the gates, and a gate's failure message names the rule it enforces.

## What this is

SketchUp-IFC-Manager is a SketchUp extension (Ruby) that edits IFC data on SketchUp entities and
exports the model to IFC. `src/bt_ifcmanager.rb` registers it and holds `VERSION`;
`src/bt_ifcmanager/lib/lib_ifc/` is the IFC engine, where `*_su.rb` files are SketchUp-coupled and
the rest is pure Ruby. `lib/rubyzip/` and `lib/rubyzip-1.3.0/` are both intentional: `loader.rb`
picks 1.3.0 on Ruby below 2.4.

## Supported platform

SketchUp **2017 Make and up**, which pins Ruby 2.2.4 (2017, 2018), 2.5.1 (2019, 2020), 2.7.x
(2021 to 2023) and 3.2.2 (2024 to 2026). Everything under `src/` and `test/` runs on Ruby 2.2:
no `&.`, `<<~`, `dig`, `clamp`, `then`, unary-plus strings or `delete_prefix`. `rake compat` fails
on APIs that do not exist there or were removed by 3.2, and names the version.

## Commands

Development Ruby is 3.2 (`.ruby-version`). `bundle install` once, then:

| Command | What it proves |
|---|---|
| `bundle exec rake` | rubocop, compat and the unit tests, the same thing CI's `gate` runs |
| `bundle exec rake test` | `test/run.rb`: every `test/unit/**/*_test.rb`, no SketchUp needed; exits 2 on zero files |
| `bundle exec rake compat` | no Ruby 2.3+ or removed-in-3.2 API under `src/` |
| `bundle exec rake rubocop` | style and SketchUp API pitfalls; offences that predate the gate live in `.rubocop_todo.yml`, which may shrink and not grow |

On Windows without the MSYS2 devkit: `bundle config set --local without 'development documentation'`
first. CI runs on Linux and installs everything.

## The real gates

- `gate` in `.github/workflows/ci.yml` is required by the `main` ruleset: the Ruby 3.2 leg runs
  `bundle exec rake`, the Ruby 2.2 leg runs `ruby -c` over `src/` and `test/run.rb` in a
  `ruby:2.2` container. Nothing else blocks a merge, and nothing here runs inside SketchUp.
- `release.yml` runs on a `v*` tag, refuses a tag that differs from `VERSION`, and opens a draft
  release a person publishes.
- Never unblock a stuck PR by editing the ruleset; push a commit or reopen the PR instead.

## Writing

- Ruby files start with `# frozen_string_literal: true`, a blank line, then `# Purpose: <why, max
  80 chars>`.
- Plain hyphens, never em-dashes; no AI attribution in commits or PR text.
- A test asserts behaviour through a real input or a stated invariant, never a stub's return value.
- A regression test names its issue: `test_issue_123_...`.
