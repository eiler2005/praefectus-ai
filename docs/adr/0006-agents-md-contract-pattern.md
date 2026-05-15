# ADR-0006: `AGENTS.md` as a hard contract for LLM agents

**Status:** Accepted
**Date:** 2026-05-01

## Context

LLM agents (Claude Code, Codex, Cursor, custom in-house bots) increasingly drive infrastructure operations. They share a failure mode: confident, plausible-looking actions that violate constraints the operator never had to articulate before — "obviously you don't `git push --force` to main", "obviously you don't edit the application owner's compose file".

Without a structured place to write these constraints down:

- Each agent rediscovers them by trial and error.
- Each operator ends up writing the same correction over and over.
- The rules drift between agents and across sessions of the same agent.

The community has converged on a convention: a top-level `AGENTS.md` file (similar to `CLAUDE.md` for Claude Code, but tool-agnostic) that the agent reads before doing work.

## Decision

PraefectusAI treats [`AGENTS.md`](../../AGENTS.md) as the **system prompt of the repository**. Every agent — Claude Code, Codex, Cursor, or any other — is expected to read it first. It encodes:

1. **Project snapshot** — what this repo is, what it owns, what it does not.
2. **Karpathy-style workflow rules** — think before acting, read first, minimal change, surgical edits, verifiable goals.
3. **Hard safety rules** — never `git push` without approval, never `docker volume prune`, never edit `/opt/<app>/docker-compose.yml`, etc. Each rule states *what* and implicitly *why*.
4. **Secrets and privacy** — what counts as a secret, where it lives, how to reference it in docs.
5. **Architecture invariants** — the assumptions that must hold across all changes.
6. **Where things live** — index of every directory and its purpose.
7. **Read-only checks** — commands the agent may run without confirmation.

Tool-specific files (`CLAUDE.md`, `.cursorrules`, etc.) are kept short and import `AGENTS.md` rather than duplicating its rules.

The contract is enforceable at three levels:

- **Convention** — agents read `AGENTS.md` because their host instructions tell them to.
- **Documentation** — `CONTRIBUTING.md` references it; reviewers reject PRs that violate its rules.
- **CI** — `secret-scan` automates one of the rules ("no real secrets"); future hooks will automate more.

## Consequences

**Positive:**

- Agents arrive with shared context. The same correction is not made twice.
- Operators have a single place to add a rule when a new failure mode is discovered. The fix is durable, not lost in chat history.
- Reviewing PRs from an unfamiliar agent or operator is faster — the reviewer just checks that the change respects `AGENTS.md`.
- The pattern transfers — projects that adopt PraefectusAI's structure can copy `AGENTS.md` and customise it.

**Negative:**

- The contract is only as strong as the agent's compliance. A misconfigured agent or one with a bad system prompt can ignore it.
- Maintaining `AGENTS.md` is itself work. As patterns evolve, the file must evolve too — stale rules are worse than no rules.
- Some rules (e.g. "never edit `/opt/<app>/docker-compose.yml`") are platform-specific. A fork that uses Kubernetes instead of Docker Compose must rewrite this section, not just delete it.
