#!/usr/bin/env python3

import os
import json
import time
import requests

ENV_BORDER0_TOKEN = "BORDER0_TOKEN"
ENV_BORDER0_API_URL = "BORDER0_API_URL"

def create_policy(token: str, name: str, policy_data: dict, expiry: int):
    response = requests.post(
        url=f"{os.environ.get(ENV_BORDER0_API_URL, "https://api.border0.com/api/v1")}/policies",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json={
            "name": name,
            "description": "Test policy for expiring-policies demo",
            "socket_ids": [], # none
            "org_wide": False,
            "policy_data": policy_data,
            "version": "v2",
            "expiry": expiry,
        },
    )
    if response.status_code == 201:
        print("Policy created successfully!")
    else:
        print(f"Failed to create policy: {response.status_code}")
        try:
            print(response.json())
        except json.JSONDecodeError:
            print(response.text)

def get_policy_data(email: str) -> dict:
    return {
        "condition": {
            "who": {
                "email": [ email ],
                "group": [],
                "service_account": []
            }
        },
        "permissions": {
            "database": {},
            "http": {},
            "kubernetes": {},
            "network": {},
            "rdp": {},
            "ssh": {
                "docker_exec": {},
                "exec": {},
                "kubectl_exec": {},
                "sftp": {},
                "shell": {},
                "tcp_forwarding": {}
            },
            "tls": {},
            "vnc": {}
        }
    }

if __name__ == "__main__":
    token = os.environ.get(ENV_BORDER0_TOKEN, '')
    if not token:
        raise Exception(f"Required environment variable {ENV_BORDER0_TOKEN} is not set")
    
    now_unix = int(time.time())

    create_policy(
        token=token,
        name=f"my-test-policy-{now_unix}",
        policy_data=get_policy_data("adriano@border0.com"),
        expiry=now_unix+5*60, # expire 5 minutes from now
    )
