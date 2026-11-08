PREFIX  ?= /usr/local
DESTDIR ?=
BINDIR   = $(DESTDIR)$(PREFIX)/bin
MANDIR   = $(DESTDIR)$(PREFIX)/share/man/man1
BASHDIR  = $(DESTDIR)$(PREFIX)/share/bash-completion/completions
ZSHDIR   = $(DESTDIR)$(PREFIX)/share/zsh/site-functions

.PHONY: install uninstall test lint check

install:
	install -Dm755 bin/dirsweep $(BINDIR)/dirsweep
	install -Dm644 man/dirsweep.1 $(MANDIR)/dirsweep.1
	install -Dm644 completions/dirsweep.bash $(BASHDIR)/dirsweep
	install -Dm644 completions/_dirsweep $(ZSHDIR)/_dirsweep

uninstall:
	rm -f $(BINDIR)/dirsweep $(MANDIR)/dirsweep.1 $(BASHDIR)/dirsweep $(ZSHDIR)/_dirsweep

lint:
	shellcheck -S warning bin/dirsweep tests/*.sh

test:
	bash tests/run_tests.sh

check: lint test
