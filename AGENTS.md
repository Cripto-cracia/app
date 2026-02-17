# AGENTS.md — Cripto-cracia/app

## Code Style

### Markdown (markdownlint)

- **MD040**: Always add a language specifier to fenced code blocks.
  - For ASCII diagrams or plain text, use ` ```text `.
  - For Dart code, use ` ```dart `.
  - For shell commands, use ` ```bash ` or ` ```sh `.
  - Never leave a bare ` ``` ` without a language identifier.

### Dart

- Run `dart format .` before committing.
- Run `flutter analyze` (or `dart analyze lib/`) — zero warnings allowed.
- Run `flutter test` — all tests must pass.

## Commits

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat`, `fix`, `docs`, `test`, `refactor`, `chore`.
- Keep commits atomic and well-scoped.

## PRs

- All GitHub activity (PRs, commits, comments, reviews) in **English**.
- Do not amend + force-push on open PRs — use additional commits.
- Every PR should include or update a doc in `docs/` explaining the change.
