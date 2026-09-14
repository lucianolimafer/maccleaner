# Repository Working Agreement

## Language

- Use English for source code, UI copy, documentation, tests, branches, pull requests, and commit messages.
- Keep identifiers and technical terminology concise and idiomatic.

## Collaboration

- Use multiple agents only for independent, bounded tasks.
- Keep one agent responsible for reviewing and applying commits.
- The commit agent must inspect the complete staged diff, run relevant checks, and reject mixed or incomplete changes.
- Preserve user changes and never rewrite unrelated work.

## Commits

- Use Conventional Commits: `type(scope): imperative summary`.
- Prefer `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`, `perf`, and `style`.
- Keep commits atomic and split unrelated changes.
- Never add assistant attribution, AI co-author trailers, generated-by notices, prompt text, conversation logs, or tool-specific metadata.

## Quality Gate

- Run `swift test` for source changes.
- Run `swift build -c release` for changes affecting the executable or packaging.
- Run `git diff --check` before committing.
- Do not commit `.build`, DerivedData, local settings, screenshots, or temporary files.
