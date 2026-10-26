# List All Sockets (reliable cursor pagination)

`list_all_services.sh` lists every socket in your organization by walking the
`GET /api/v1/sockets` endpoint in **cursor mode**.

Unlike page/offset pagination, cursor mode orders results by an immutable key and seeks past the
last socket seen, so a full multi-page scan will not skip or duplicate sockets even if sockets are
created, deleted, or (dis)connected while the scan is running. This makes it the reliable way to
enumerate all sockets.

## Prerequisites

- `curl`
- `jq`

## Authentication

Set the authentication token using the `BORDER0_ADMIN_TOKEN` environment variable, or place the
token in a file at `~/.border0/token`:

```sh
border0 login
# or:
export BORDER0_ADMIN_TOKEN=$(cat ~/.border0/token)
```

## Usage

```sh
./list_all_services.sh [flags]
```

Each socket is printed to stdout as `<socket_id>\t<name>`; progress and totals are written to
stderr, so you can redirect just the data with `> sockets.tsv`.

### Flags

| Flag | Description |
| --- | --- |
| `--search-term <str>` | Case-insensitive substring match against a socket's `name` and `display_name`. |
| `--page-size <n>` | Sockets per request (1–100, default 100). Only changes how many round-trips the scan makes — not the total result set. |
| `--api <url>` | API base URL. Defaults to `$BORDER0_API` or `https://api.border0.com`. |
| `-h`, `--help` | Show help and exit. |

### Examples

```sh
# All sockets
./list_all_services.sh

# Only sockets whose name/display_name contains "prod"
./list_all_services.sh --search-term prod

# Smaller pages (useful to watch pagination progress)
./list_all_services.sh --search-term prod --page-size 3

# Save just the socket id/name pairs to a file
./list_all_services.sh > sockets.tsv
```

## How it works

1. The first request sends an **empty** `cursor` parameter (`?cursor=`). The presence of the
   `cursor` param — even empty — selects cursor mode and starts the scan from the beginning.
2. Each response includes an opaque `next_cursor`. The script sends it back on the next request to
   fetch the following page.
3. When `next_cursor` comes back empty (or absent), the scan is complete.

> Note: in cursor mode the `pagination.total_records` / `total_pages` fields are not populated
> (no count query is performed). The authoritative "more pages" signal is `next_cursor`.
