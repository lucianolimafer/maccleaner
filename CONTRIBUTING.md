# Contributing

## Language

Use English for source code, documentation, commit messages, branches, issues,
and pull requests.

## Development workflow

1. Keep changes focused on one meaningful implementation unit.
2. Add or update tests for behavior changes.
3. Run `swift test` before committing.
4. Commit each completed implementation unit separately.
5. Use Conventional Commits with an imperative, descriptive summary.

Examples:

- `feat(cleanup): add safe cache validation`
- `refactor(scanner): extract storage service`
- `fix(dashboard): improve empty states`

Avoid mixing unrelated refactors and product changes in the same commit.

Do not include assistant attribution, AI co-author trailers, generated-by notices,
prompt text, conversation logs, or tool-specific metadata in repository content.
