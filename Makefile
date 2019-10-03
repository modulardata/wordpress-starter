GULP  := $(PWD)/node_modules/.bin/gulp
WPCLI := $(PWD)/dwp

THEME_NAME := md-starter-theme
THEME_DIR  := app/wp-content/themes/$(THEME_NAME)

.PHONY: deps
deps: node_modules $(THEME_DIR)/vendor

node_modules: package.json yarn.lock
	@yarn install
	@touch $@

app/index.php:
	@$(WPCLI) core download --locale=fr_FR --version=5.2.3

app/wp-config.php:
	@$(WPCLI) core config --dbname=wordpress --dbuser=root --dbpass=password --dbhost=mysqldb --locale=fr_FR
	@$(WPCLI) core install --url=localhost:3010 --title=MDstarter --admin_user=admin --admin_password=password --admin_email=admin@md-starter-theme.com --skip-email

$(THEME_DIR)/vendor: $(THEME_DIR)/composer.json $(THEME_DIR)/composer.lock
	@cd $(THEME_DIR); composer install

## Get everything ready (Docker containers, WordPress download
## and configuration)
.PHONY: setup
setup: up_docker deps app/index.php app/wp-config.php
	@$(WPCLI) theme activate md-starter-theme
	@$(WPCLI) menu create "navbar"
	@$(WPCLI) menu item add-post navbar 2
	@$(WPCLI) menu create "navbar_footer"
	@$(WPCLI) menu item add-post navbar_footer 2
	@$(WPCLI) rewrite structure '/%year%/%monthnum%/%day%/%postname%/' --hard

.PHONY: build_docker
build_docker: .build_docker.mk

.build_docker.mk: Dockerfile docker-compose.yml
	@sudo HOST_UID=$(shell id -u) HOST_USER=$(shell whoami) docker-compose build
	touch $@

.PHONY: up_docker
up_docker: build_docker
	@HOST_UID=$(shell id -u) HOST_USER=$(shell whoami) docker-compose up -d

.DEFAULT_GOAL := serve
## Serve:
## - WordPress front-office at http://localhost:3000 with live reloading
## - WordPress back-office at http://localhost:3010/wp-admin
##   (username: admin, password: password)
## - phpMyAdmin at http://localhost:3011
.PHONY: serve
serve: deps up_docker
	@$(GULP) --continue

## Build WordPress theme for production use
.PHONY: build
build: deps
	@NODE_ENV=production $(GULP)

.PHONY: install_wpcs
install_wpcs: $(THEME_DIR)/vendor
	@cd $(THEME_DIR); composer create-project wp-coding-standards/wpcs:dev-master --no-dev

define primary
\033[38;2;166;204;112;1m$(1)\033[0m
endef

define title
\033[38;2;255;204;102m$(1)\033[0m\n
endef

## List available commands
.PHONY: help
help:
	@printf "$(call primary,wordpress-starter)\n"
	@printf "A starter template for WordPress websites using Make\n\n"
	@printf "$(call title,USAGE)"
	@printf "    make <SUBCOMMAND>\n\n"
	@printf "$(call title,SUBCOMMANDS)"
	@awk '\
	BEGIN { \
		longuestHelpCommandLength = 0; \
		helpIndex =0; \
		helpCommands[""] = 0; \
		helpMessages[""] = 0; \
	}\
	function addToCommandsMessages(){\
		if (helpMessage) { \
			helpCommands[helpIndex] = helpCommand;\
			helpMessages[helpIndex] = helpMessage;\
			\
			helpCommandLength = length(helpCommand); \
			if (helpCommandLength > longuestHelpCommandLength) { \
				longuestHelpCommandLength = helpCommandLength;\
			} \
			\
			helpIndex++; \
			helpMessage = ""; \
		} \
	} \
	{ \
		line = $$0; \
		while((n = index(line, "http")) > 0) { \
			if (match(line, "https?://[^ ]+")) { \
			  url = substr(line, RSTART, RLENGTH); \
			  sub(url, "\033[38;2;119;168;217m"url"\033[0m", $$0);  \
			  line = substr(line, n + RLENGTH); \
			} else {\
				break; \
			} \
		} \
		\
		if ($$0 ~ /^.PHONY: [a-zA-Z\-\_0-9]+$$/) { \
			helpCommand = substr($$0, index($$0, ":") + 2); \
			addToCommandsMessages();\
		} else if ($$0 ~ /^[a-zA-Z\-\_0-9.]+:/) { \
			helpCommand = substr($$0, 0, index($$0, ":")); \
			addToCommandsMessages();\
		} else if ($$0 ~ /^##/) { \
			if (helpMessage) { \
				helpMessage = helpMessage "\n" substr($$0, 3); \
			} else { \
				helpMessage = substr($$0, 3); \
			} \
		} \
	} \
	END { \
		for (i in helpCommands) {	\
			if (i != ""){	\
				printf "    \033[38;2;166;204;112;1m%-"longuestHelpCommandLength"s\033[0m", helpCommands[i]; \
				split(helpMessages[i], splitedHelpMessages, "\n"); \
				for (y in splitedHelpMessages){ \
					if (y == 1){ \
						printf "   %s\n", splitedHelpMessages[y];\
					} else { \
						printf "   %"longuestHelpCommandLength"s    %s\n", "", splitedHelpMessages[y];\
					} \
				} \
			} \
		} \
	}' \
	$(MAKEFILE_LIST)
