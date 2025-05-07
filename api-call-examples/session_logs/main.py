import requests
import os
import datetime
import json
import concurrent.futures
import pathlib
import argparse
from dataclasses import dataclass, field
from typing import Dict, Any, Set, TypedDict, TypeAlias

BORDER0_API_TOKEN = os.environ.get("BORDER0_API_TOKEN", "")
BORDER_API_URL = os.environ.get("BORDER_API_URL", "https://api.border0.com/api/v1")

SessionID: TypeAlias = str
SessionDict: TypeAlias = Dict[str, Any]

class APIError(Exception):
    """Exception raised for Border0 API errors."""
    pass

class NotFoundError(Exception):
    """Exception raised for Border0 Not FOUND API errors."""
    pass


@dataclass
class StateManager:
    state_file_path: str = "app_state.json"
    last_run_time: str | None = None
    processed_session_ids: Set[SessionID] = field(default_factory=set)
    processed_session_ids_map: Dict[SessionID, bool] = field(default_factory=dict)

    def load_state(self) -> None:
        """Load application state from file if it exists."""
        state_path = pathlib.Path(self.state_file_path)
        if not state_path.exists():
            return

        try:
            state_data = json.loads(state_path.read_text())
            self.last_run_time = state_data.get("last_run_time")
            self.processed_session_ids = set(state_data.get("processed_session_ids", []))
            self.processed_session_ids_map = {session_id: True for session_id in self.processed_session_ids}
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading state: {e}")

    def save_state(self) -> None:
        """Save current application state to file."""

        state_data: dict[str, Any] = {
            "last_run_time": self.last_run_time,
            "processed_session_ids": list(self.processed_session_ids)
        }
        try:
            pathlib.Path(self.state_file_path).write_text(json.dumps(state_data, indent=2))
        except IOError as e:
            print(f"Error saving state: {e}")

    def update_run_time(self) -> None:
        """Update last run time to current UTC time."""
        self.last_run_time = datetime.datetime.now(datetime.UTC).isoformat()

    def add_processed_session(self, session_id: SessionID) -> None:
        """Mark a session as processed."""
        self.processed_session_ids.add(session_id)
        self.processed_session_ids_map[session_id] = True

    def is_session_processed(self, session_id: SessionID) -> bool:
        """Check if a session has been processed."""
        return self.processed_session_ids_map.get(session_id, False)


class SessionFilter(TypedDict, total=False):
    """SessionFilter: session filter parameters."""
    start_date: str
    end_date: str
    finished: bool


class Border0API:
    def __init__(self, token: str, border0_api_url: str | None = None):
        self.token = token
        self.border0_api_url = border0_api_url or BORDER_API_URL

    def api_request(self, endpoint: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        """Make a request to the Border0 API."""
        url = f"{self.border0_api_url}/{endpoint}"
        headers = {
            "x-access-token": self.token,
            "accept": "application/json",
        }
        response = requests.get(url, headers=headers, params=params)

        match response.status_code:
            case 200:
                return response.json()
            case 500:
                raise APIError(f"Server error (500): {response.text}")
            case 404:
                raise NotFoundError(f"Not found: {response.text}")
            case _:
                raise APIError(f"API request failed with status code {response.status_code}: {response.text}")

    def get_sessions(self, page: int, page_size: int, filters: SessionFilter | None = None) -> list[SessionDict]:
        """Get a list of sessions with optional filtering."""
        endpoint = "sessions"
        params: dict[str, Any] = {
            "page": page,
            "page_size": page_size,
        }

        if filters:
            params |= {k: v for k, v in filters.items() if v is not None}

            if finished := filters.get("finished"):
                match finished:
                    case "true":
                        params["finished"] = True
                    case "false":
                        params["finished"] = False

        response_data = self.api_request(endpoint, params)
        return response_data.get("session_logs", [])

    def get_session_recording(self, socket_id: str, session_id: str, recording_id: str | None = None, format: str | None = None) -> dict[str, Any] | None:
        """Get recording data for a session."""
        endpoint = f"session/{socket_id}/{session_id}/session_log"
        params = {}
        if recording_id:
            params["recording_id"] = recording_id
        if format:
            params["format"] = format

        if params:
            endpoint += f"?{requests.compat.urlencode(params)}"

        try:
            return self.api_request(endpoint)
        except Exception:
            return None


def parse_jsonl_recording_data(recording: str) -> list[dict]:
    """Parse recording data from JSONL format to a list of dictionaries."""
    if not recording:
        return []

    recording_list = []
    for line in recording.strip().split("\n"):
        if not line:
            continue

        try:
            recording_list.append(json.loads(line))
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON line: {e}")

    return recording_list


def fetch_session_recordings(border0_api: Border0API, session: SessionDict) -> SessionDict:
    """Fetch recordings for a single session."""
    socket_id = session["socket_id"]
    session_id = session["session_id"]
    recordings = session.get("recordings", [])
    session_copy = session.copy()

    for recording in recordings:
        recording_id = recording.get("recording_id")
        if not recording_id:
            continue
        # return the text format if the recording type is asciinema
        session_format = "text" if recording.get("recording_type") == "asciinema" else ""

        if recording_data := border0_api.get_session_recording(socket_id, session_id, recording_id, session_format):
            # Don't try to parse if the session format is text
            if session_format == "text":
                recording["recording_data"] = recording_data
            else:
                recording["recording_data"] = parse_jsonl_recording_data(recording_data)
        else:
            recording["recordings_data"] = []

    return session_copy


def load_processed_sessions(output_file: str) -> list[SessionDict]:
    """Load processed sessions from a JSON file."""
    path = pathlib.Path(output_file)
    if not path.exists():
        return []

    try:
        return json.loads(path.read_text())
    except (IOError, json.JSONDecodeError) as e:
        print(f"Error loading processed sessions: {e}")
        return []


def save_processed_session(sessions: list[SessionDict], output_file: str) -> None:
    """Save processed sessions to a JSON file."""
    try:
        pathlib.Path(output_file).write_text(json.dumps(sessions, indent=2))
    except IOError as e:
        print(f"Error saving processed sessions: {e}")


def main() -> None:
    """Main application entry point."""
    parser = argparse.ArgumentParser(description="Border0 Session Logger")
    parser.add_argument("--output-file", help="Path to output file for processed sessions", default=None)
    args = parser.parse_args()

    if not BORDER0_API_TOKEN:
        raise ValueError("BORDER0_API_TOKEN environment variable is not set.")

    state_manager = StateManager()
    state_manager.load_state()

    border0_api = Border0API(BORDER0_API_TOKEN)

    # Use last run time as start_date if available, otherwise use 1 day ago window
    yesterday = datetime.datetime.now(datetime.UTC) - datetime.timedelta(days=1)

    # RFC3339 format by explicitly formatting with Z for UTC timezone
    start_date = state_manager.last_run_time or yesterday.strftime("%Y-%m-%dT%H:%M:%SZ")
    end_date = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

    filters: SessionFilter = {
        start_date: start_date,
        end_date: end_date
    }

    try:
        sessions = border0_api.get_sessions(page=1, page_size=100, filters=filters)
    except NotFoundError:
        print("No sessions found")
        return
    except APIError as e:
        print(f"Error fetching sessions: {e}")
        return

    new_sessions = [session for session in sessions
                   if not state_manager.is_session_processed(session["session_id"])]

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = list()
        for session in new_sessions:
            session["session_log_type"] = "session_started" if session.get("end_time", "") == "" else "session_completed"
            futures.append(executor.submit(fetch_session_recordings, border0_api, session))

        updated_sessions = []
        for future in concurrent.futures.as_completed(futures):
            if updated_session := future.result():
                state_manager.add_processed_session(updated_session["session_id"])
                updated_sessions.append(updated_session)

    state_manager.update_run_time()
    state_manager.save_state()

    # Write to output file
    output_file = args.output_file or "processed_sessions.json"
    if updated_sessions:
        sessions = load_processed_sessions(output_file)
        sessions.extend(updated_sessions)
        save_processed_session(sessions, output_file)
        print(f"Wrote {len(updated_sessions)} new sessions to {output_file}")


if __name__ == "__main__":
    main()
