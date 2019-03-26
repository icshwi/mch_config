EXPECT_SRC		:= expect
SCRIPT_SRC		:= script
CONFIG_SRC		:= src
SHARE_DESTDIR	:= mch_config
EXPECT_DESTDIR	:= expect
SRC_DESTDIR 	:= src

EXPECT_SRC_FILES	:= $(wildcard $(EXPECT_SRC)/*.exp)
CONFIG_SRC_FILES	:= $(wildcard $(CONFIG_SRC)/*.txt)
SCRIPT_SRC_FILES	:= $(SCRIPT_SRC)/wsmanager.bash

ifeq ($(PREFIX),)
	PREFIX := /usr/local
endif

.PHONY: all install

all: install

install:
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/bin/
	install -m 645 $(SCRIPT_SRC)/mch_config.bash $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/bin/
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	install -m 644 $(EXPECT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	install -m 644 $(CONFIG_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	install -d 644 $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_SRC)
	install -m 645 $(SCRIPT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_SRC)
	install -d 644 $(SCRIPT_SRC)/websocketd.service /etc/systemd/system/

