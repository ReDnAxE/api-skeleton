## Project Makefile
## ————————————————————————————————————————————————————————————————————————


## Setup ————————————————————————————————————————————————————————————————————————
DOCKER_COMPOSE_DEV     = docker-compose -f docker/docker-compose.dev.yml
DOCKER_COMPOSE_TEST     = docker-compose -p docker_test -f docker/docker-compose.test.yml
EXEC_BACK          = $(DOCKER_COMPOSE_DEV) exec -w /var/www/back web
EXEC_COMPOSER      = docker run --rm -it -u $$(id -u):$$(id -g) -v $$PWD/:/back -v ~/.composer:/root/.composer -w /back composer:latest composer
.DEFAULT_GOAL      = help
#.PHONY

## Support args for commands ————————————————————————————————————————————————————————————————————————
SUPPORTED_COMMANDS := back-composer
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
## Back
## ————————————————————————————————————————————————————————————————————————
##
back-clear-cache: ## Clear the cache
	$(EXEC_BACK) bin/console c:c

back-fix-perm: ## Fix permissions on var/*
	$(EXEC_BACK) chmod -R 777 var/*

back-purge: ## Purge cache
	$(EXEC_BACK) rm -rf var/cache

back-clean-all: ## Clear all caches, Doctrine and redis then fix permission
	$(EXEC_BACK) bin/deploy.sh

back-composer:
	$(EXEC_COMPOSER) $(COMMAND_ARGS)

##
## Tests
## ————————————————————————————————————————————————————————————————————————
##
test-docker-up: ##Init tests docker containers
	$(DOCKER_COMPOSE_TEST) up -d --remove-orphans

test-docker-down: ##Init tests docker containers
	$(DOCKER_COMPOSE_TEST) down -v

test-db-init: test-docker-up ##Init db
	$(DOCKER_COMPOSE_TEST) exec -w /var/www/back web bin/init.sh

test-back: test-docker-up debug-php-test-off test-back-unit test-back-int  ## Run tests (use "make -i" to ignore errors and continue)

test-back-unit: test-docker-up debug-php-test-off ## Run unit tests
	$(DOCKER_COMPOSE_TEST) exec -w /var/www/back web vendor/bin/phpunit -c . --testsuite unit

test-back-int: test-docker-up debug-php-test-off test-db-init ## Run functional tests
	$(DOCKER_COMPOSE_TEST) exec -w /var/www/back web vendor/bin/phpunit -c . --testsuite int

test-back-coverage: test-docker-up debug-php-test-on test-back-unit-coverage test-back-int-coverage ## Run tests with coverage (use "make -i" to ignore errors and continue)

test-back-unit-coverage: test-docker-up debug-php-test-on ## Run back unit test with html coverage report
	$(DOCKER_COMPOSE_TEST) exec -w /var/www/back web vendor/bin/phpunit -c . --coverage-html tests/coverage/unit --testsuite unit

test-back-int-coverage: test-docker-up test-db-init debug-php-test-on ## Run back integration test with html coverage report
	$(DOCKER_COMPOSE_TEST) exec -w /var/www/back web vendor/bin/phpunit -c . --coverage-html tests/coverage/int --testsuite int

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