
# Border0 API Examples and Management Scripts

This repository contains examples and scripts for managing Border0 connectors, service accounts, and tokens through the Border0 API. The scripts demonstrate how to create connectors, generate tokens, and create various types of sockets, as well as how to manage service accounts and tokens.

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

## Scripts Overview

### 1. Connector and Sockets Management Script

This Python script allows you to manage Border0 connectors and sockets through the Border0 API. The script creates a connector, generates a token for it, and creates various types of sockets attached to the connector.

#### Usage

Run the script to create a connector, generate a token for it, and create various types of sockets attached to the connector.

```sh
python3 playground_connector_with_sockets.py
```

#### Example Output

The script will output commands to start the connector and information about the created sockets. For example:

```sh
To start the connector execute:

BORDER0_TOKEN=<connector_token> border0 connector start

Created ssh socket <socket_id> with DNS <dns_name> attached to connector <connector_id>.
Created http socket <socket_id> with DNS <dns_name> attached to connector <connector_id>.
Created mysql socket <socket_id> with DNS <dns_name> attached to connector <connector_id>.
...
```

#### Supported Socket Types

The script currently supports the following socket types:
- SSH
- HTTP
- MySQL
- PostgreSQL
- VNC
- RDP
- TLS
- Kubernetes

### 2. Service Accounts and Tokens Management Script

This Python script allows you to manage Border0 service accounts and tokens through the Border0 API. You can create and delete service accounts and tokens using command-line options.

#### Usage

Run the script with the appropriate options to manage service accounts and tokens.

#### Creating a Service Account and Token

To create a service account and a token for it, use the `--create` option along with `--account-name`, `--description`, `--role`, and `--token-name` options.

```sh
python3 script.py --create --account-name <account-name> --description "<description>" --role <role> --token-name <token-name>
```

#### Deleting a Service Account

To delete a service account, use the `--delete` option along with the `--account-name` option.

```sh
python3 script.py --delete --account-name <account-name>
```

#### Deleting a Token from a Service Account

To delete a token from a service account, use the `--delete` option along with `--account-name` and `--token-name` options.

```sh
python3 script.py --delete --account-name <account-name> --token-name <token-id>
```

