# SYNCRO Makefile — standard entry points for users + CI.
PREFIX ?= $(HOME)/.local

.PHONY: help check lint test install uninstall version

help:
	@printf 'Targets:\n'
	@printf '  make check    syntax check all shell files\n'
	@printf '  make lint     shellcheck (if installed)\n'
	@printf '  make test     run mock test suite (no device needed)\n'
	@printf '  make install  user-local install (PREFIX=~/.local)\n'
	@printf '  make uninstall  remove installed files\n'
	@printf '  make version  print version\n'

check:
	sh -n bin/syncro lib/*.sh install.sh uninstall.sh tests/*.sh

lint:
	command -v shellcheck >/dev/null 2>&1 || { printf 'shellcheck not installed, skipping\n'; exit 0; }; \
	shellcheck -S warning bin/syncro lib/*.sh install.sh uninstall.sh

test: check
	sh tests/test_args.sh
	sh tests/test_device.sh
	sh tests/test_config.sh
	sh tests/test_network.sh
	sh tests/test_os.sh

install:
	sh install.sh --prefix="$(PREFIX)"

uninstall:
	sh uninstall.sh --prefix="$(PREFIX)"

version:
	@cat VERSION
