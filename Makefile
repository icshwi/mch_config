EXPECT_SRC		:= expect
SCRIPT_SRC		:= script
CONFIG_SRC		:= src
SHARE_DESTDIR	:= mch_config
EXPECT_DESTDIR	:= expect
SRC_DESTDIR 	:= src

EXPECT_SRC_FILES	:= $(wildcard $(EXPECT_SRC)/*.exp)
CONFIG_SRC_FILES	:= $(wildcard $(CONFIG_SRC)/*.txt)

LOG_PREFIX	?= /tmp/mch_cfg

ifeq ($(PREFIX),)
	PREFIX := /usr/local
endif

.PHONY: all patch install

all: patch install

patch:
	sed -i "s|SRC_PREFIX=..\/src|SRC_PREFIX=$(DESTDIR)$(PREFIX)\/share\/$(SHARE_DESTDIR)\/$(SRC_DESTDIR)|g" $(SCRIPT_SRC)/mch_config.bash
	sed -i "s|EXPECT_PREFIX=..\/expect|EXPECT_PREFIX=$(DESTDIR)$(PREFIX)\/share\/$(SHARE_DESTDIR)\/$(EXPECT_DESTDIR)|g" $(SCRIPT_SRC)/mch_config.bash
	sed -i "s|LOG_PREFIX=\"../.*\"|LOG_PREFIX=$(LOG_PREFIX)|g" $(SCRIPT_SRC)/mch_config.bash
	$(foreach f,$(EXPECT_SRC_FILES),$(shell sed -i "s|logfile_path \"log_path\"|logfile_path \"$(LOG_PREFIX)\/elog\"|g" $(f)))

install:
	install -d $(DESTDIR)$(PREFIX)/bin/
	install -m 645 $(SCRIPT_SRC)/mch_config.bash $(DESTDIR)$(PREFIX)/bin/
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	install -m 644 $(EXPECT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	install -m 644 $(CONFIG_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)

