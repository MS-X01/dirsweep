# Contributing

Bug reports and pull requests are welcome.

## Before you open a PR

```bash
make check        # shellcheck + the test suite
```

Both must pass. The suite builds its own throwaway directory trees under
`/tmp`; it never touches anything else.

## Ground rules

- **A change in behaviour needs a test.** `tests/run_tests.sh` is plain bash;
  copy the nearest block and adjust it.
- **Safety beats convenience.** This tool deletes things. If a change makes
  deletion more likely in a corner case, it needs a good argument and an opt-in
  flag, not a new default.
- Keep it one file with no dependencies beyond bash 4.4+ and GNU coreutils/
  findutils. That is a feature.
- Keep the user-facing text short and boring. No emoji in output.

## Reporting a bug

Include `dirsweep --version`, your distro, the exact command, and ideally the
output of the same command with `-d -v`. If a directory was removed that should
not have been, say what was inside it.

For security problems see [SECURITY.md](SECURITY.md).
