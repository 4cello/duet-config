#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_DIRS = ["/sys", "/macros"]
TIMEOUT = 30


class IgnoreFilter:
    def __init__(self, repo):
        self.repo = repo
        self.enabled = (repo / ".gitignore").is_file()

    def ignores(self, path):
        if not self.enabled:
            return False

        relative = path.relative_to(self.repo).as_posix()
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "-q", "--", relative],
            cwd=self.repo,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise RuntimeError(f"Could not check .gitignore for {relative}")
        return result.returncode == 0


def load_dotenv(path):
    """Load simple KEY=VALUE entries without overriding the process environment."""
    try:
        lines = path.read_text().splitlines()
    except FileNotFoundError:
        return

    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        key, separator, value = line.partition("=")
        if not separator or not key.strip():
            continue
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        else:
            value = value.split(" #", 1)[0].rstrip()
        os.environ.setdefault(key, value)


def prettify_json(path, content):
    if path.suffix.lower() != ".json":
        return content
    data = json.loads(content)
    return (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


class Duet:
    def __init__(self, url, password):
        self.url = url.rstrip("/")
        self.password = password

    def request(self, endpoint, params=None):
        query = urllib.parse.urlencode(params or {})
        url = f"{self.url}/{endpoint}"
        if query:
            url += "?" + query

        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return response.read()

    def connect(self):
        data = json.loads(self.request("rr_connect", {"password": self.password}))
        if data.get("err") != 0:
            raise RuntimeError("Duet authentication failed")

    def disconnect(self):
        try:
            self.request("rr_disconnect")
        except Exception:
            pass

    def list_directory(self, directory):
        files = []
        first = 0

        while True:
            data = json.loads(
                self.request("rr_filelist", {"dir": directory, "first": first})
            )

            if data.get("err", 0) != 0:
                raise RuntimeError(f"Cannot list {directory}: {data}")

            files.extend(data.get("files", []))
            next_index = data.get("next", 0)

            if not next_index:
                break

            first = next_index

        return files

    def download(self, remote_path):
        return self.request("rr_download", {"name": remote_path})

    def upload(self, remote_path, content):
        query = urllib.parse.urlencode({"name": remote_path})
        req = urllib.request.Request(
            f"{self.url}/rr_upload?{query}", data=content, method="POST"
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            result = json.loads(response.read())
        if result.get("err", 0) != 0:
            raise RuntimeError(f"Cannot upload {remote_path}: {result}")

    def download_tree(self, directory, destination, ignore_filter):
        destination.mkdir(parents=True, exist_ok=True)

        entries = self.list_directory(directory)
        remote_names = set()

        for entry in entries:
            name = entry["name"]
            kind = entry["type"]

            # Reject unexpected paths from the controller.
            if name in (".", "..") or "/" in name or "\\" in name:
                raise RuntimeError(f"Unexpected filename: {name}")

            remote_names.add(name)

            remote = directory.rstrip("/") + "/" + name
            local = destination / name
            if ignore_filter.ignores(local):
                continue

            if kind == "d":
                if local.is_symlink() or (local.exists() and not local.is_dir()):
                    local.unlink()
                self.download_tree(remote, local, ignore_filter)
            elif kind == "f":
                if local.is_symlink():
                    local.unlink()
                elif local.is_dir():
                    shutil.rmtree(local)
                content = self.download(remote)
                content = prettify_json(local, content)
                local.write_bytes(content)
                print(f"Downloaded {remote}")

        # This directory mirrors the Duet directory, so remove local entries
        # that are no longer present remotely (including stale subdirectories).
        for local in destination.iterdir():
            if local.name in remote_names or ignore_filter.ignores(local):
                continue
            if local.is_dir() and not local.is_symlink():
                shutil.rmtree(local)
            else:
                local.unlink()

    def upload_tree(self, directory, source, ignore_filter):
        if not source.is_dir():
            raise RuntimeError(f"Local directory does not exist: {source}")

        for local in sorted(source.rglob("*")):
            if local.is_symlink():
                continue
            if ignore_filter.ignores(local):
                continue
            if not local.is_file():
                continue
            relative = local.relative_to(source).as_posix()
            remote = directory.rstrip("/") + "/" + relative
            content = prettify_json(local, local.read_bytes())
            self.upload(remote, content)
            print(f"Uploaded {remote}")


def main():
    load_dotenv(Path(__file__).parent / ".env")
    parser = argparse.ArgumentParser(
        description="Synchronise Duet configuration into Git"
    )
    parser.add_argument(
        "--url", default=os.getenv("DUET_URL"), help="DWC URL, e.g. http://192.168.1.50"
    )
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload local files to the Duet instead of downloading from it",
    )
    parser.add_argument(
        "--password",
        default=os.getenv("DUET_PASSWORD"),
        help="Duet machine password (or DUET_PASSWORD)",
    )
    parser.add_argument("--directory", type=Path, help="Local repository directory")
    parser.add_argument(
        "--dirs", nargs="+", default=DEFAULT_DIRS, help="Remote directories to download"
    )
    parser.add_argument(
        "git_args", nargs=argparse.REMAINDER, help="Git command and arguments"
    )

    args = parser.parse_args()

    if not args.url:
        parser.error("--url or DUET_URL is required")

    password = args.password
    if not password:
        print("Warning: Duet password is empty.", file=sys.stderr)
        password = ""

    repo = args.directory or (Path(__file__).parent)
    repo.mkdir(parents=True, exist_ok=True)

    duet = Duet(args.url, password)
    ignore_filter = IgnoreFilter(repo)

    try:
        duet.connect()

        for remote_dir in args.dirs:
            remote_dir = "/" + remote_dir.strip("/")
            local_dir = repo / remote_dir.lstrip("/")
            if args.upload:
                duet.upload_tree(remote_dir, local_dir, ignore_filter)
            else:
                duet.download_tree(remote_dir, local_dir, ignore_filter)

    finally:
        duet.disconnect()

    if not (repo / ".git").exists():
        subprocess.run(["git", "init"], cwd=repo, check=True)

    git_args = args.git_args
    if git_args and git_args[0] == "--":
        git_args = git_args[1:]

    if not git_args:
        git_args = ["status"]

    sys.exit(subprocess.run(["git", *git_args], cwd=repo).returncode)


if __name__ == "__main__":
    main()
