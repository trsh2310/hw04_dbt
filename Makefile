SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
VENV ?= ../.venv
export DBT_PROFILES_DIR := .
export DBT_SEND_ANONYMOUS_USAGE_STATS := false
DBT := $(VENV)/bin/dbt
SQLFLUFF := $(VENV)/bin/sqlfluff
PYTHON := $(VENV)/bin/python
CSV ?= ../../kaffka_hw02/data/train.csv

.PHONY: install up down load deps debug seed run test unit build docs serve lint fix parse check all
install:
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -r requirements.txt
up:
	docker compose up -d --wait
down:
	docker compose down
load:
	$(PYTHON) scripts/load_source.py --csv "$(CSV)"
deps:
	$(DBT) deps
debug:
	$(DBT) debug
seed:
	$(DBT) seed
run:
	$(DBT) run
test:
	@mkdir -p evidence
	set -o pipefail; $(DBT) --no-use-colors test 2>&1 | tee evidence/dbt_test.log
unit:
	$(DBT) test --select test_type:unit
build:
	$(DBT) build
docs:
	$(DBT) docs generate
serve:
	$(DBT) docs serve --port 8084 --no-browser
lint:
	$(SQLFLUFF) lint models macros tests
fix:
	$(SQLFLUFF) fix models macros tests
parse:
	$(DBT) parse
check: lint test
all: deps seed run test lint docs

.PHONY: pre-commit-config
pre-commit-config:
	$(VENV)/bin/pre-commit validate-config .pre-commit-config.yaml
