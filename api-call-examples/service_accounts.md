
# Border0 Service Accounts and Tokens Management Script

This Python3 script allows you to manage Border0 service accounts and tokens through the Border0 API. You can create and delete service accounts and tokens using command-line options.

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

Run the script with the appropriate options to manage service accounts and tokens.

### Creating a Service Account (optionally, creating a token)

To create a service account, use the `--create` option along with `--account-name`, `--description`, and `--role` options. You can also optionally create a token by providing `--token-name`.

```sh
python3 script.py --create --account-name <account-name> --description "<description>" --role <role> [--token-name <token-name>]
```

Example:

```sh
python3 script.py --create --account-name my-python-service-account --description "Some awesome description" --role admin --token-name my-python-service-account-token
```

### Deleting a Service Account

To delete a service account, use the `--delete` option along with the `--account-name` option.

```sh
python3 script.py --delete --account-name <account-name>
```

Example:

```sh
python3 script.py --delete --account-name my-python-service-account
```

### Deleting a Token from a Service Account

To delete a token from a service account, use the `--delete` option along with `--account-name` and `--token-name` options.

```sh
python3 script.py --delete --account-name <account-name> --token-name <token-id>
```

Example:

```sh
python3 script.py --delete --account-name my-python-service-account --token-name cba233c9-119e-477a-82a5-15d91e802ae5
```

## Script Options

- `-c`, `--create`: Create a service account (optionally, create a token).
- `-d`, `--delete`: Delete a service account or token.
- `-a`, `--account-name`: Specify the service account name.
- `-t`, `--token-name`: Specify the token name or ID.
- `--description`: Provide a description for the service account (required for creation).
- `--role`: Specify the role for the service account (required for creation). Options are `admin`, `member`, `client`.

## Example

### Create a Service Account (optionally, create a token)

```sh
python3 script.py --create --account-name my-python-service-account --description "Some awesome description" --role admin --token-name my-python-service-account-token
```

### To add another token to the same service account

```sh
python3 script.py --create --account-name my-python-service-account --token-name my-python-service-account-token-2
```


### Delete a Service Account

```sh
python3 script.py --delete --account-name my-python-service-account
```

### Delete a Token from a Service Account

```sh
python3 script.py --delete --account-name my-python-service-account --token-name cba233c9-119e-477a-82a5-15d91e802ae5
```