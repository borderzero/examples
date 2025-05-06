run: create-venv
	. experiment-env/bin/activate; \
	pip3 install -r requirements.txt; \
	python3 main.py

create-venv:
	@if [ -z "$$VIRTUAL_ENV" ] || [ "$$(basename $$VIRTUAL_ENV)" != "experiment-env" ]; then \
		echo "The 'experiment-env' virtual environment is not activated, setting up..."; \
		python3 -m venv experiment-env; \
	else \
		echo "The 'experiment-env' virtual environment is already activated, skipping setup..."; \
	fi

clean:
	@rm -rf experiment-env
	@rm -rf __pycache__
	@rm -rf .ipynb_checkpoints
	@echo "Cleaned up the virtual environment and temporary files."
