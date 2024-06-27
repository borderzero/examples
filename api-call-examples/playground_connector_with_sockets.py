#!/usr/bin/env python3

import os
import random
import string
import time
import datetime
import requests

# Ensure the token is available
token = os.getenv("BORDER0_ADMIN_TOKEN")
if not token:
    try:
        with open(os.path.expanduser("~/.border0/token"), "r") as file:
            token = file.read().strip()
    except FileNotFoundError:
        print(
            "Token not found. Ensure BORDER0_ADMIN_TOKEN environment variable is set or ~/.border0/token file exists."
        )
        exit(1)

# Base URL and Headers
base_url = "https://api.border0.com/api/v1"
headers = {
    "accept": "application/json",
    "Authorization": f"Bearer {token}",
}


def random_string(length=10):
    letters = string.ascii_lowercase
    return "".join(random.choice(letters) for i in range(length))


def create_connector():
    connector_data = {
        "name": f"connector-{random_string()}",
        "description": f"description-for-the-connector-{random_string()}",
        "built_in_ssh_service_enabled": True,
    }
    response = requests.post(
        f"{base_url}/connector", headers=headers, json=connector_data
    )
    if response.status_code != 200:
        print(f"Error creating connector: {response.text}")
        return None
    return response.json()["connector_id"]


def create_connector_token(connector_id, token_name):
    lifetime_minutes = random.randint(800, 1440)
    expires_at = int(
        time.mktime(
            (
                datetime.datetime.utcnow()
                + datetime.timedelta(minutes=lifetime_minutes)
            ).timetuple()
        )
    )
    token_data = {
        "connector_id": connector_id,
        "name": token_name,
        "expires_at": expires_at,
    }
    response = requests.post(
        f"{base_url}/connector/token", headers=headers, json=token_data
    )
    if response.status_code != 200:
        print(f"Error creating connector token: {response.text}")
        return None
    return response.json()["token"]


def create_socket(connector_id, socket_type, socket_config):
    socket_data = {
        "name": f"python3-{socket_type}-{random_string()}",
        "socket_type": socket_type if "sql" not in socket_type else "database",
        "recording_enabled": False,
        "connector_authentication_enabled": False,
        "connector_id": connector_id,
        "upstream_configuration": socket_config,
        "tags": {
            "origin": "python3",
            "border0_client_subcategory": "The Cloud",
            "border0_client_category": "Playground",
        },
    }

    response = requests.post(f"{base_url}/socket", headers=headers, json=socket_data)
    if response.status_code != 200:
        print(f"Error creating {socket_type} socket: {response.text}")
        return None, None
    result = response.json()
    return result["socket_id"], result["dnsname"]


def main():
    connector_id = create_connector()
    if not connector_id:
        print("Failed to create connector.")
        exit(1)

    connector_token = create_connector_token(
        connector_id, f"token-name-{random_string()}"
    )
    if not connector_token:
        print("Failed to create connector token.")
        exit(1)

    print(
        f"To start the connector execute: \n\n BORDER0_TOKEN={connector_token} border0 connector start \n"
    )

    socket_configs = {
        "ssh": {
            "service_type": "ssh",
            "ssh_service_configuration": {
                "ssh_service_type": "standard",
                "standard_ssh_service_configuration": {
                    "hostname": "ssh.playground.border0.io",
                    "port": 22,
                    "ssh_authentication_type": "username_and_password",
                    "username_and_password_auth_configuration": {
                        "username": "border0",
                        "password": "Border0<3Ssh",
                    },
                },
            },
        },
        "http": {
            "service_type": "http",
            "http_service_configuration": {
                "http_service_type": "standard",
                "standard_http_service_configuration": {
                    "host_header": "localhost",
                    "hostname": "http.playground.border0.io",
                    "port": 80,
                },
            },
        },
        "mysql": {
            "service_type": "database",
            "database_service_configuration": {
                "database_service_type": "standard",
                "standard_database_service_configuration": {
                    "authentication_type": "username_and_password",
                    "hostname": "mysql.playground.border0.io",
                    "port": 3306,
                    "protocol": "mysql",
                    "username_and_password_auth_configuration": {
                        "username": "border0",
                        "password": "Border0<3MySql",
                    },
                },
            },
        },
        "pgsql": {
            "service_type": "database",
            "database_service_configuration": {
                "database_service_type": "standard",
                "standard_database_service_configuration": {
                    "authentication_type": "username_and_password",
                    "hostname": "psql.playground.border0.io",
                    "port": 5432,
                    "protocol": "postgres",
                    "username_and_password_auth_configuration": {
                        "username": "border0",
                        "password": "Border0<3Psql",
                    },
                },
            },
        },
        "vnc": {
            "service_type": "vnc",
            "vnc_service_configuration": {
                "hostname": "vnc.playground.border0.io",
                "port": 5900,
                "vnc_authentication_type": "password",
                "password_auth_configuration": {
                    "password": "Border0<3VNC",
                },
            },
        },
        "rdp": {
            "service_type": "rdp",
            "rdp_service_configuration": {
                "hostname": "rdp.playground.border0.io",
                "port": 3389,
                "rdp_authentication_type": "password",
                "password_auth_configuration": {
                    "password": "Border0<3RDP",
                },
            },
        },
        "tls": {
            "service_type": "tls",
            "tls_service_configuration": {
                "tls_service_type": "standard",
                "standard_tls_service_configuration": {
                    "hostname": "tls.playground.border0.io",
                    "port": 9000,
                },
            },
        },
    }

    # Loop through all the socket types
    socket_types = map(str.lower, socket_configs.keys())
    for socket_type in socket_types:
        try:
            socket_id, socket_dns = create_socket(
                connector_id, socket_type, socket_configs[socket_type]
            )
            if socket_id and socket_dns:
                print(
                    f"Created {socket_type} socket {socket_id} with DNS {socket_dns} attached to connector {connector_id}."
                )
            else:
                print(f"Failed to create {socket_type} socket.")
        except Exception as e:
            print(f"An error occurred while creating {socket_type} socket: {str(e)}")


if __name__ == "__main__":
    main()
