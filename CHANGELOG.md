# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [4.0.0] - 2026-11-05

First public release. This is a ground-up rewrite of the private 3.x script;
the options you knew are still there, but several behaviours changed on purpose.

### Fixed
- Dry runs now match real runs. Before, junk-only directories and the parents
  that would become empty were left out, so a preview could report less than
  half of what a real run removed.
- `--min-age` no longer skips parents of removed directories. Deleting a child
  bumped the parent's mtime and made it look new; times are now read from a
  snapshot taken before anything is deleted.
- Interactive mode read its answers from the `find` stream instead of the
  terminal, and asked about directories that were not going to be removed.
- Trash restore recreated paths wrongly, and junk files were deleted for good
  even in trash mode. Undo now rebuilds directories from a manifest (mode,
  owner and mtime included) and moves junk back.
- A non-interactive run without `--yes` used to default to "yes". It now
  refuses.
- The target directory itself was removed when it ended up empty. It never is.
- Exclusion regexes matched the absolute path, so a target such as
  `/srv/cache-app` was skipped entirely by `-e cache`. They now match the path
  relative to the target and cover everything below a match.
- Config files were `source`d (arbitrary code execution) and loaded after the
  command line, silently overriding it. They are now parsed as plain data and
  loaded first.
- JSON report did not escape paths and wrote `"null"` as a string.
- Empty mount points were reported as removal failures; they are skipped.

### Changed
- Renamed from `clean_empty_dirs.sh` to `dirsweep`.
- Root is no longer required. Logs, locks and trash fall back to the XDG
  directories for normal users.
- Removed risky default junk patterns: `*.lock`, `*.pid`, `*.cache`, `*.old`
  and `core`. A directory holding only `yarn.lock` is not junk. Add them back
  with `-j` if you want them.
- `-T` now takes a required directory; `-t` turns trash mode on with an
  automatic location.
- Protected paths are checked as trees (`/etc`, `/usr/share`, ...) and after
  symlink resolution, so `/bin` on a merged-usr system is covered.
- Requires bash 4.4+ and GNU find.

### Added
- `--undo` and `--restore SESSION`.
- Several targets in one run, positional paths, `--opt=value`, combined short
  flags (`-dvy`).
- `--min-age` accepts units (`12h`, `2w`).
- `--list-junk`, `--no-default-junk`, `-j` for your own patterns.
- Config file support, `--no-config`.
- Man page, bash and zsh completion, `make install`.
- Banner on interactive runs and in `--help`; `--banner` prints it, `--no-banner`
  or `banner = false` turns it off. Never shown when stdout is not a terminal.
- Test suite (126 checks) and GitHub Actions workflow.
- Exit status 1 when any removal failed, 130 on interrupt.

## [3.0] - private

Single-file script. Not published.
