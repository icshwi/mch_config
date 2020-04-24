TOP:=$(CURDIR)

include $(TOP)/CONFIG

EXPECT_SRC	 := $(TOP)/expect
SCRIPT_SRC	 := $(TOP)/script
CONFIG_SRC	 := $(TOP)/src
SHARE_DESTDIR	 := mch_config
EXPECT_DESTDIR	 := expect
SRC_DESTDIR 	 := src
SCRIPT_DESTDIR   := script
WEBUI_SRC	 := $(TOP)/webui

EXPECT_SRC_FILES := $(wildcard $(EXPECT_SRC)/*.exp)
EXPECT_SRC_FILES := $(EXPECT_SRC_FILES) $(EXPECT_SRC)/expect.config
CONFIG_SRC_FILES := $(wildcard $(CONFIG_SRC)/*.txt)
SCRIPT_SRC_FILES := $(SCRIPT_SRC)/wsmanager.bash $(SCRIPT_SRC)/mch_config.bash $(SCRIPT_SRC)/jiraHandler.py \
                    $(SCRIPT_SRC)/newissue.json $(SCRIPT_SRC)/csentryHandler.py

APACHE_DIR	 := /var/www/html

TFTP_IPADDR_TXT = $(SCRIPT_SRC)/.tftp_ip.txt

ifeq ($(PREFIX),)
	PREFIX := /usr/local
endif

.PHONY: all install deploy uninstal undeploy getip

all: install deploy

# Install&Uninstall are related to the commandline tool
install: | path setip
	sudo install -m 644 $(TFTP_IPADDR_TXT)  $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_DESTDIR)/
	sudo install -m 644 $(EXPECT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	sudo install -m 644 $(CONFIG_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	sudo install -m 645 $(SCRIPT_SRC_FILES) $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_DESTDIR)
	sudo cp -r $(WEBUI_SRC)/* $(APACHE_DIR)/

uninstall:
	sudo rm -rf $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)

# The following rules are related to the web interface
deploy: | path
	${SCRIPT_SRC}/install_websocketd.bash
	${SCRIPT_SRC}/install_webui.bash
	sudo cp -r $(WEBUI_SRC)/* $(APACHE_DIR)/
	sudo install -m 645 $(SCRIPT_SRC)/websocketd.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable websocketd.service
	@echo "Now try to start the websocketd service"

undeploy: uninstall
	sudo systemctl disable websocketd.service
	sudo rm /etc/systemd/system/websocketd.service
	sudo systemctl daemon-reload
	@echo "If you don't need anymore the Apache server, you should remove it manually"

path:
	sudo install -m 755 -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/bin/
	sudo install -m 755 -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(EXPECT_DESTDIR)
	sudo install -m 755 -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SRC_DESTDIR)
	sudo install -m 755 -d $(DESTDIR)$(PREFIX)/share/$(SHARE_DESTDIR)/$(SCRIPT_DESTDIR)

getip:
	@ipaddr="";\
	ipaddr=$$(ip addr show eno1 | grep -Po 'inet \K[\d.]+');\
	echo "$$ipaddr";

setip:
	@echo "TFTP_IP_ADDRS=$(TFTP_SERVER)" > $(TFTP_IPADDR_TXT)

patch:
	@sed -e "s|\(ws://\)\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\(.*\)|\1${WEBSOCKET}\3|g" -i $(WEBUI_SRC)/scripts/handler.js
	@echo "\033[1mPatched IP address in the JS handler\033[0m"

config:
	@echo "Setting up environment variables for the Expect scripts"
	@sed -E "s|(G_EXPECT_CFG_LOGFILEPATH )(.?)*$ |\1$(EXPECT_LOG_PATH)|g" -i $(CONFIG_SRC)/expect.config
	@sed -E "s|(G_EXPECT_CFG_TFTPADDR )(.?)*$ |\1$(TFTP_SERVER)|g" -i $(CONFIG_SRC)/expect.config
