
# Border0 Connector and Sockets Management Script

This Python script allows you to manage Border0 connectors and sockets through the Border0 API. The script creates a connector, generates a token for it, and creates various types of sockets attached to the connector.

## Prerequisites

- Python 3.x
- `requests` library (`pip install requests`)

## Setup

1. **Clone the repository:**

    ```sh
    git clone https://github.com/borderzero/examples.git borderzero/examples
    cd borderzero/examples
    ```

2. **Set the authentication token:**

    You can set the authentication token using the `BORDER0_ADMIN_TOKEN` environment variable or by placing the token in a file located at `~/.border0/token`.

    ```sh
    border0 login
    ```
    The script will use the token from the file `~/.border0/token` by default or you can set the token using the environment variable `BORDER0_ADMIN_TOKEN` as follows:
    ```sh
    export BORDER0_ADMIN_TOKEN=$(cat ~/.border0/token)
    ```

## Usage

Run the script to create a connector, generate a token for it, and create various types of sockets attached to the connector.

### Creating a Connector and Sockets

Simply run the script:

```sh
python3 playground_connector_with_sockets.py
```

## Example Output

The script will output commands to start the connector and information about the created sockets. For example:

```sh
To start the connector execute:

BORDER0_TOKEN=<connector_token> border0 connector start

Created ssh socket <socket_id> with DNS <dns_name> attached to connector <connector_id>.
Created http socket <socket_id> with DNS <dns_name> attached to connector <connector_id>.
Created mysql socket <socket_id> with DNS <dns_name> attached to connector <connector_id>.
...
```

## Error Handling

The script includes error handling to ensure it continues running even if the creation of some sockets fails. Errors are logged to the console.

## Supported Socket Types

The script currently supports the following socket types:
- SSH
- HTTP
- MySQL
- PostgreSQL
- VNC
- RDP
- TLS
