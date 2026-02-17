# tests/

Test suites using [bats-core](https://github.com/bats-core/bats-core).

## Conventions

- `unit/` — unit tests for bash library functions (fast, no external deps)
- `integration/` — full bootstrap tests (require Docker, slower)
- Test file naming: `test_<module>.sh`
- Use `bats` assertions: `[ "$status" -eq 0 ]`, `[[ "$output" =~ pattern ]]`
- Each test must be independent (no shared state between tests)
- Source tested libraries with relative paths from test files

## Running

```bash
make test              # Unit tests only
make test-unit         # Same as above
make test-integration  # Docker required
bats tests/unit/       # Direct bats invocation
```
