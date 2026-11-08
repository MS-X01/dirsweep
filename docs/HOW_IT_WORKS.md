# How dirsweep works

This page explains what the tool does between you pressing Enter and a
directory disappearing, and where it deliberately stops.

## The pass

1. **Snapshot.** `find` lists every directory under the target, deepest first,
   together with its modification time, and writes the list to a temp file.
   Nothing has been touched yet. Reading times up front matters: deleting a
   child updates its parent's mtime, which would make `--min-age` skip every
   parent in a chain.
2. **Walk the snapshot.** Because children come before parents, a directory is
   judged after everything below it has already been handled. `a/b/c` empty
   means `c`, then `b`, then `a` go in one pass.
3. **Decide per directory**, in this order, stopping at the first "no":

   | Check | Skip reason |
   |---|---|
   | is it a symlink? | `symlink` |
   | is it (inside) a protected system path? | `protected` |
   | does an `--exclude` regex match it or a parent? | `excluded` |
   | is it newer than `--min-age`? | `recent` |
   | does it contain anything that is not junk? | counted as *kept* |
   | can we write to it and its parent? | `no permission` |
   | is it a mount point? | `mount point` |
   | (interactive) did you say no? | `declined` |

4. **Act.** Junk files first (removed, or moved to the trash session), then
   `rmdir`. `rmdir` never removes a non-empty directory, so a file that
   appeared between the scan and the removal makes the removal fail instead of
   being deleted.

## What counts as junk

Only regular files and symlinks whose name matches a pattern
(`dirsweep --list-junk`). Sockets, FIFOs and device nodes are content.
A directory is junk-only when *every* entry is junk; one real file anywhere in
it and the whole directory, junk included, is left as it is.

The defaults are conservative on purpose. `*.lock`, `*.pid` and `core` are not
in the list: a directory containing only `yarn.lock` is a broken project, not
garbage, and a `.pid` file may belong to a running daemon.

`*.log` is in the list because that is what most people expect, but it is the
pattern to think about on production machines. Use `--no-default-junk`, or
`--min-age`, or `--trash`.

## Dry runs

A dry run cannot just skip the deletion, because a parent only becomes empty
once its children are gone. dirsweep keeps a set of "paths that would already
be gone" and hides them when it lists a directory, so the preview is the same
walk as the real run, minus the unlinking. The test suite checks that the two
produce the same count.

## Undo

With `--trash`, nothing is copied except junk files. Empty directories carry no
data, so they are recorded rather than moved. The session directory contains:

```
manifest      NUL-separated records: kind, mode, uid, gid, mtime, path
files/        junk files, mirrored under their original absolute path
INFO          version, time, targets
```

`kind` is `D` (directory) or `F` (junk file). Restore runs three passes:

1. recreate directories, parents first (the manifest is children-first, so it
   is read backwards)
2. move junk files back
3. apply mode, owner and mtime, last, so that restoring a child cannot change
   its parent's mtime afterwards

Existing paths are never overwritten; a conflict is reported and the item
stays in the session directory. A finished session gets a `RESTORED` marker.
`--undo` picks the newest session without one.

## Protected paths

Refused as targets: `/`, `/home`, `/root`, `/run`, `/var`, `/usr`.
Refused with everything below them: `/bin /sbin /lib* /boot /dev /proc /sys /etc`
and `/usr/{bin,sbin,lib*,libexec,share,include}`.
Targets are resolved with `realpath` first, so `/bin` on a merged-usr system
(a symlink to `/usr/bin`) is caught as well.

dirsweep's own log, JSON report, lock file and trash session are never treated
as junk, even if you point them inside the target.

## Config files are data

`key = value` lines are parsed by hand. A config file is never `source`d, so a
value like `$(rm -rf ~)` is just a string. The test suite has a case for this.

## Limits

- An empty directory that some symlink points at is removed, and the link is
  left dangling. Checking every symlink on the system would cost more than the
  tool is worth; keep such directories out with `--exclude`.
- Between the snapshot and the removal the tree can change. Directories that
  vanish are ignored; directories that gained files fail `rmdir` and are
  counted as errors.
- GNU find (`-printf`) and GNU coreutils are required. It works on Linux and
  WSL; macOS needs Homebrew's `findutils` and `coreutils` first in `PATH`.
- Directory modification time is the only age signal. It changes when entries
  are added or removed, not when a file inside is edited.

## Exit status

`0` success, `1` finished with errors (or nothing to undo), `2` usage error or
refusal, `130` interrupted.
