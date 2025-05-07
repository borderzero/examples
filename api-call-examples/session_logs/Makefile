.PHONY: setup run clean create-venv check-env validate help

ARGS?=

run: create-venv
	. experiment-env/bin/activate; \
	pip3 install -r requirements.txt; \
	python3 main.py $(ARGS)

create-venv:
	@if [ -z "$$VIRTUAL_ENV" ] || [ "$$(basename $$VIRTUAL_ENV)" != "experiment-env" ]; then \
		echo "The 'experiment-env' virtual environment is not activated, setting up..."; \
		python3 -m venv experiment-env; \
	else \
		echo "The 'experiment-env' virtual environment is already activated, skipping setup..."; \
	fi

setup: create-venv
	. experiment-env/bin/activate; \
	pip3 install -r requirements.txt

clean:
	@rm -rf experiment-env
	@rm -rf __pycache__
	@rm -rf .ipynb_checkpoints
	@rm -f app_state.json processed_sessions.json
	@echo "Cleaned up the virtual environment and temporary files."

check-env:
	@if [ -z "$$BORDER0_API_TOKEN" ]; then \
		echo "Error: BORDER0_API_TOKEN environment variable is not set"; \
		exit 1; \
	fi

validate: check-env
	@echo "Environment validated. Ready to run."

help:
	@echo "Available commands:"
	@echo "  make setup                    - Set up virtual environment and install dependencies"
	@echo "  make run [ARGS=\"...\"]        - Run the Border0 session logger with optional arguments"
	@echo "  make clean                    - Remove virtual environment, state files and temporary files"
	@echo "  make create-venv              - Create Python virtual environment if not activated"
	@echo "  make check-env                - Verify environment variables are set"
	@echo "  make validate                 - Validate environment before running"
	@echo "  make help                     - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make run ARGS=\"--output-file sessions.json\""

default: help
