# Border0 Session Logger

This tool fetches and processes session logs from the Border0 API, storing session recordings and maintaining state between runs.

## Requirements

- Python 3.10+
- Required packages (automatically installed in virtual environment):
  - requests
  - concurrent.futures (standard library)

## Setup

1. Clone this repository
2. Set up the virtual environment and install dependencies:
   ```
   make setup
   ```
3. Set your Border0 API token as an environment variable:
   ```
   export BORDER0_API_TOKEN="your_api_token"
   ```

## Usage

Run the application using make:

```
make run
```

This will automatically:
- Create or use an existing virtual environment named `experiment-env`
- Install required dependencies
- Run the main Python script

### Command-line Arguments

The application supports the following command-line arguments:

- `--output-file FILE_PATH`: Write processed sessions to the specified output file in JSON format

Example:
```
python3 main.py --output-file sessions_output.json
```

Or with make:
```
make run ARGS="--output-file sessions_output.json"
```

You can also run specific commands:

```
make create-venv  # Only create the virtual environment
make validate     # Check if required environment variables are set
make clean        # Remove virtual environment and temporary files
```

By default, the application:
- Looks for previously processed sessions in `app_state.json`
- Fetches new sessions since the last run (or from the past day if running for the first time)
- Downloads session recordings
- Saves processed sessions to `processed_sessions.json`
- Updates the state with the latest run time

## Configuration

You can configure the following environment variables:
- `BORDER0_API_TOKEN` (required): Your Border0 API token
- `BORDER0_API_URL` (optional): Custom API URL if needed (defaults to "https://api.border0.com/api/v1")

## Files

- `main.py`: Main application code
- `app_state.json`: Stores application state between runs
- `processed_sessions.json`: Stores detailed information about processed sessions
- `requirements.txt`: Python dependencies
- `Makefile`: Contains commands for running and managing the application
- `experiment-env/`: Virtual environment directory (created by setup)
