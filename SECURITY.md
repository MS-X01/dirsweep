# Security policy

dirsweep deletes files, so bugs that delete the wrong thing are treated as
security issues.

Please report them privately through GitHub: **Security → Report a
vulnerability** on this repository. Do not open a public issue for them.

Things I especially want to hear about:

- a way to make dirsweep remove or move something outside the requested target
- path handling problems (odd characters, symlinks, races between scan and
  removal)
- anything that lets a config file, exclude pattern or file name run code
- the protected-path list missing something that should be on it

You will get an answer within a few days. Fixes go into a patch release with a
note in the changelog.

Only the latest release is supported.
