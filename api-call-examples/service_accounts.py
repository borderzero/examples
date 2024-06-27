#!/usr/bin/env python3

import os
import argparse
import requests

API_BASE_URL = "https://api.border0.com/api/v1/organizations/iam/service_accounts"

def get_auth_token():
    token = os.getenv("BORDER0_ADMIN_TOKEN")
    if token is None:
        try:
            with open(os.path.expanduser("~/.border0/token"), "r") as file:
                token = file.read().strip()
        except FileNotFoundError:
            print("Token not found. Ensure BORDER0_ADMIN_TOKEN environment variable is set or ~/.border0/token file exists.")
            return None
    return token

def create_service_account(name, description, role):
    url = API_BASE_URL
    payload = {
        "description": description,
        "name": name,
        "role": role
    }
    headers = {
        "accept": "application/json",
        "Authorization": get_auth_token(),
        "Content-Type": "application/json"
    }
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error creating service account: {e.response.text}")
        return None

def create_token(service_account_name, token_name, expires_at=0):
    url = f"{API_BASE_URL}/{service_account_name}/tokens"
    payload = {
        "expires_at": expires_at,
        "name": token_name
    }
    headers = {
        "accept": "application/json",
        "Authorization": get_auth_token(),
        "Content-Type": "application/json"
    }
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error creating token: {e.response.text}")
        return None

def list_service_accounts():
    headers = {
        "accept": "application/json",
        "Authorization": get_auth_token()
    }
    try:
        response = requests.get(API_BASE_URL, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error listing service accounts: {e.response.text}")
        return None

def list_tokens(service_account_name):
    url = f"{API_BASE_URL}/{service_account_name}/tokens"
    headers = {
        "accept": "application/json",
        "Authorization": get_auth_token()
    }
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error listing tokens: {e.response.text}")
        return None

def delete_service_account(service_account_name):
    url = f"{API_BASE_URL}/{service_account_name}"
    headers = {
        "accept": "application/json",
        "Authorization": get_auth_token()
    }
    try:
        response = requests.delete(url, headers=headers)
        response.raise_for_status()
        return response.status_code == 204
    except requests.exceptions.RequestException as e:
        print(f"Error deleting service account: {e.response.text}")
        return False

def delete_token(service_account_name, token_id):
    url = f"{API_BASE_URL}/{service_account_name}/tokens/{token_id}"
    headers = {
        "accept": "application/json",
        "Authorization": get_auth_token()
    }
    try:
        response = requests.delete(url, headers=headers)
        response.raise_for_status()
        return response.status_code == 204
    except requests.exceptions.RequestException as e:
        print(f"Error deleting token: {e.response.text}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Manage Border0 Service Accounts and Tokens")
    parser.add_argument("-c", "--create", action="store_true", help="Create a service account or token")
    parser.add_argument("-d", "--delete", action="store_true", help="Delete a service account or token")
    parser.add_argument("-a", "--account-name", type=str, help="Service account name", required=True)
    parser.add_argument("-t", "--token-name", type=str, help="Token name or ID")
    parser.add_argument("--description", type=str, help="Service account description")
    parser.add_argument("--role", type=str, help="Service account role (admin, member, client)")
    
    args = parser.parse_args()

    if args.create:
        if args.description and args.role:
            created_service_account = create_service_account(args.account_name, args.description, args.role)
            if created_service_account:
                print("Created Service Account:", created_service_account)
                if args.token_name:
                    created_token = create_token(args.account_name, args.token_name)
                    if created_token:
                        print("Created Token:", created_token)
                    else:
                        print("Failed to create token.")
            else:
                print("Failed to create service account.")
        elif args.token_name:
            created_token = create_token(args.account_name, args.token_name)
            if created_token:
                print("Created Token:", created_token)
            else:
                print("Failed to create token.")
        else:
            print("For creating a service account, you must provide --account-name, --description, and --role.")
            print("For creating a token, you must provide --account-name and --token-name.")
    
    elif args.delete:
        if args.token_name:
            # Delete token
            if delete_token(args.account_name, args.token_name):
                print("Token deleted successfully.")
            else:
                print("Failed to delete token.")
        else:
            # Delete service account
            if delete_service_account(args.account_name):
                print("Service Account deleted successfully.")
            else:
                print("Failed to delete Service Account.")
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
