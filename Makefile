## Copyright 2015-2016 Carnë Draug
## Copyright 2015-2016 Oliver Heimlich
## Copyright 2025 Torsten Lilge
##
## Copying and distribution of this file, with or without modification,
## are permitted in any medium without royalty provided the copyright
## notice and this notice are preserved.  This file is offered as-is,
## without any warranty.

PACKAGE := $(shell grep "^[Nn]ame: " DESCRIPTION | cut -f2 -d" ")
VERSION := $(shell grep "^[Vv]ersion: " DESCRIPTION | cut -f2 -d" ")

TARGET_DIR      := target
RELEASE_DIR     := $(TARGET_DIR)/$(PACKAGE)-$(VERSION)
RELEASE_TARBALL := $(TARGET_DIR)/$(PACKAGE)-$(VERSION).tar.gz

INST            := $(wildcard inst/*)

OCTAVE ?= octave --silent

.PHONY: dist install clean

help:
	@echo " "
	@echo "Targets:"
	@echo " "
	@echo "   dist      - Create $(RELEASE_TARBALL) for release"
	@echo "   install   - Install the package in GNU Octave"
	@echo "   clean     - Remove releases files"
	@echo " "

%.tar.gz: %
	@echo "Create $@ ..."
	@tar -c -f - --posix -C "$(TARGET_DIR)/" "$(notdir $<)" | gzip -9n > "$@"

$(RELEASE_DIR): .git/index
	@echo "Creating package dist directory $@ ..."
	@-$(RM) -r $@
	@mkdir -p $@
	@echo "  git archive ..."
	@git archive -o $@/tmp.tar HEAD
	@cd $@ && tar -xf tmp.tar && $(RM) tmp.tar
	@chmod -R a+rX,u+w,go-w "$@"

dist: doc $(RELEASE_TARBALL)

install: dist $(RELEASE_TARBALL)
	@echo 'Installing package "${RELEASE_TARBALL}" locally ...'
	@$(OCTAVE) --eval 'pkg ("install", "${RELEASE_TARBALL}")'

clean:
	$(RM) -r $(TARGET_DIR)
