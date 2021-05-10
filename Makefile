## Project Makefile
## ————————————————————————————————————————————————————————————————————————


## Setup ————————————————————————————————————————————————————————————————————————
DOCKER_COMPOSE_DEV     = docker-compose -f docker-compose.yml -f docker-compose.dev.yml
DOCKER_COMPOSE_TEST    = docker-compose -p docker_test -f docker-compose.test.yml
EXEC_API               = $(DOCKER_COMPOSE_DEV) exec php
EXEC_COMPOSER          = $(EXEC_API) composer
.DEFAULT_GOAL          = help
#.PHONY

## Support args for commands ————————————————————————————————————————————————————————————————————————
SUPPORTED_COMMANDS := api-composer api-behat
SUPPORTS_MAKE_ARGS := $(findstring $(firstword $(MAKECMDGOALS)), $(SUPPORTED_COMMANDS))
ifneq "$(SUPPORTS_MAKE_ARGS)" ""
  COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(COMMAND_ARGS):;@:)
endif

help: ## Outputs help
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

##
## Docker
## ————————————————————————————————————————————————————————————————————————
##
docker-start: ## Start the project
	docker-sync start
	$(DOCKER_COMPOSE_DEV) up -d --remove-orphans --no-recreate

docker-stop: ## Stop the project
	$(DOCKER_COMPOSE_DEV) stop
	docker-sync stop
	docker-sync clean

docker-kill: ## Destroy the project
	@$(DOCKER_COMPOSE_DEV) kill
	@$(DOCKER_COMPOSE_DEV) down --volumes --remove-orphans
	docker-sync stop
	docker-sync clean

docker-php-sh: ## Exec container sh
	$(EXEC_API) sh

##
## Git utils
## ————————————————————————————————————————————————————————————————————————
##
git-list-local-merged: ## List all merged local branch on master
	-git fetch -p && git branch --merged master | grep origin | egrep -v '>|master|develop|recette|recette-bis|release|((^feature|^hotfix|^fix|^task)/(.+))' | cut -d/ -f2-

git-list-remote-merged: ## List all merged remote branch on master
	-git fetch -p && git branch -r --merged origin/master | grep origin | egrep -v '>|master|develop|recette|recette-bis|release|((^feature|^hotfix|^fix|^task)/(.+))' | cut -d/ -f2-

git-clean-local: ## Clean all local branches merge on master except master/develop/recette/release
	-git fetch -p && git branch --merged master | grep origin | egrep -v '>|master|develop|recette|recette-bis|release|((^feature|^hotfix|^fix|^task)/(.+))' | cut -d/ -f2- | xargs git branch -d

git-clean-remote: ## Clean all remote branches merge on master except master/develop/recette/release
	-git fetch -p && git branch -r --merged origin/master | grep origin | egrep -v '>|master|develop|recette|recette-bis|release|((^feature|^hotfix|^fix|^task)/(.+))' | cut -d/ -f2- | xargs git push origin --delete

##
## Api
## ————————————————————————————————————————————————————————————————————————
##
api-clear-cache: ## Clear the cache
	$(EXEC_API) bin/console c:c

api-fix-perm: ## Fix permissions on var/*
	$(EXEC_API) chmod -R 777 var/*

api-purge: ## Purge cache
	$(EXEC_API) rm -rf var/cache

api-clean-all: ## Clear all caches, Doctrine and redis then fix permission
	$(EXEC_API) bin/deploy.sh

api-composer: ## Api composer command with args
	$(EXEC_API) composer $(COMMAND_ARGS)

##
## Tests
## ————————————————————————————————————————————————————————————————————————
##

api-behat: ## Api Behat test launcher
	$(EXEC_API) bin/behat

##
## Debug
## ————————————————————————————————————————————————————————————————————————
##
debug-php-test-on: ## Enable xdebug on test environment
	$(DOCKER_COMPOSE_TEST) exec web sh -c 'printf "zend_extension=/usr/lib64/php/modules/xdebug.so\
	\nxdebug.mode=\"coverage\"" > /etc/php.d/15-xdebug.ini'

debug-php-dev-on: ## Enable xdebug on dev environment
	export DOCKER_GATEWAY_IP=`docker network inspect docker_default | grep Gateway | grep -oh '\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}'`;\
	$(DOCKER_COMPOSE_DEV) exec web sh -c 'printf "zend_extension=/usr/lib64/php/modules/xdebug.so\
	\nxdebug.mode=debug\
	\nxdebug.log=/tmp/xdebug.log\
	\nxdebug.remote_log=/tmp/xdebug_remote.log\
	\nxdebug.client_host='$${DOCKER_GATEWAY_IP}'\
	\nxdebug.client_port=9000\
	\nxdebug.start_with_request=trigger" > /etc/php.d/15-xdebug.ini'
	$(DOCKER_COMPOSE_DEV) restart web

debug-php-dev-off: ## Disable xdebug in dev environment
	$(DOCKER_COMPOSE_DEV) exec web sh -c 'printf ";zend_extension=/usr/lib64/php/modules/xdebug.so" > /etc/php.d/15-xdebug.ini'
	$(DOCKER_COMPOSE_DEV) restart web

debug-php-test-off: ## Disable xdebug in test environment
	$(DOCKER_COMPOSE_TEST) exec web sh -c 'printf ";zend_extension=/usr/lib64/php/modules/xdebug.so" > /etc/php.d/15-xdebug.ini'