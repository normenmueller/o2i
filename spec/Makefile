PREFIX ?= $(HOME)/.local
DESTDIR ?=
CABAL ?= cabal
INSTALL ?= install

O2I_COMPONENT := o2i-cli:exe:o2i
O2I_INSTALL_PATH := $(DESTDIR)$(PREFIX)/bin/o2i

.PHONY: install uninstall

install:
	$(CABAL) build $(O2I_COMPONENT)
	$(INSTALL) -d "$(dir $(O2I_INSTALL_PATH))"
	$(INSTALL) -m 0755 "$$($(CABAL) list-bin $(O2I_COMPONENT))" \
		"$(O2I_INSTALL_PATH)"

uninstall:
	$(RM) "$(O2I_INSTALL_PATH)"
