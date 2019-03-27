EXPECT_SRC		:= expect
SCRIPT_SRC		:= script
CONFIG_SRC		:= src
SHARE_DESTDIR	:= mch_config
EXPECT_DESTDIR	:= expect
SRC_DESTDIR 	:= src
WEBUI_SRC		:= webui

EXPECT_SRC_FILES	:= $(wildcard $(EXPECT_SRC)/*.exp)
CONFIG_SRC_FILES	:= $(wildcard $(CONFIG_SRC)/*.txt)
SCRIPT_SRC_FILES	:= $(SCRIPT_SRC)/wsmanager.bash $(SCRIPT_SRC)/mch_config.bash

APACHE_DIR		:= /var/www/html

ifeq ($(PREFIX),)
	PREFIX := /usr/local
endif

.PHONY: all install deploy uninstal undeploy

all: install deploy

# Install&Uninstall are related to the commandline tool
install:
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/bin/
	install -m 645 $(SCRIPT_SRC)/mch_config.bash $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/bin/
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	install -m 644 $(EXPECT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	install -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	install -m 644 $(CONFIG_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	install -d 644 $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_SRC)
	install -m 645 $(SCRIPT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_SRC)

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)

# The following rules are related to the web interface
deploy:
	${SCRIPT_SRC}/install_websocketd.bash
	${SCRIPT_SRC}/install_webui.bash
	cp -r $(WEBUI_SRC)/* $(APACHE_DIR)/
	install -m 645 $(SCRIPT_SRC)/websocketd.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable websocketd.service
	@echo "Now try to start the websocketd service"

undeploy: uninstall
	sudo systemctl disable websocketd.service
	sudo rm /etc/systemd/system/websocketd.service
	sudo systemctl daemon-reload
	@echo "If you don't need anymore the Apache server, you should remove it manually"
