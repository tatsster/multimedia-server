#!/usr/bin/env python3
"""
Weekly healthy/easy-prep Mealie recipe importer for T4tsster.

Keeps this intentionally simple:
- uses a curated URL list from reliable recipe sites
- skips URLs already present in Mealie
- imports at most MAX_IMPORTS_PER_RUN recipes each run
- tags imported recipes with Healthy, Easy Prep, Low Oil, High Protein, plus protein tags when possible

Required env:
  MEALIE_URL
  MEALIE_API_TOKEN
Optional env:
  MAX_IMPORTS_PER_RUN=3
  MEALIE_RECIPE_URL_FILE=/path/to/urls.txt
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_URL_FILE = Path(__file__).with_name("weekly_recipe_urls.txt")
DEFAULT_MAX_IMPORTS = 3
DEFAULT_TAGS = ["Healthy", "Easy Prep", "Low Oil", "High Protein"]
TIMEOUT = 45


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value.rstrip("/") if name == "MEALIE_URL" else value


def request_json(method: str, url: str, token: str, payload: dict | None = None) -> tuple[int, dict | list | str]:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        # Cloudflare can reject Python's default urllib user-agent.
        "User-Agent": "Mozilla/5.0 (compatible; T4tsster-Mealie-WeeklyImporter/1.0)",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            if not body:
                return resp.status, {}
            try:
                return resp.status, json.loads(body)
            except json.JSONDecodeError:
                return resp.status, body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = body
        return exc.code, parsed


def normalize_url(url: str) -> str:
    parsed = urllib.parse.urlsplit(url.strip())
    return urllib.parse.urlunsplit((parsed.scheme.lower(), parsed.netloc.lower(), parsed.path.rstrip("/"), parsed.query, ""))


def existing_org_urls(mealie_url: str, token: str) -> set[str]:
    status, data = request_json("GET", f"{mealie_url}/api/recipes?perPage=-1", token)
    if status != 200 or not isinstance(data, dict):
        raise SystemExit(f"Failed to list Mealie recipes: HTTP {status} {data}")
    urls: set[str] = set()
    for item in data.get("items", []):
        org_url = (item.get("orgURL") or item.get("orgUrl") or "").strip()
        if org_url:
            urls.add(normalize_url(org_url))
    return urls


def read_candidates(path: Path) -> list[str]:
    urls: list[str] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        urls.append(line)
    return urls


def protein_tags(url: str) -> list[str]:
    u = url.lower()
    tags: list[str] = []
    if any(word in u for word in ["chicken", "turkey"]):
        tags.append("Chicken")
    if any(word in u for word in ["beef", "steak", "meatball"]):
        tags.append("Beef")
    if any(word in u for word in ["fish", "salmon", "tilapia", "cod", "shrimp", "tuna"]):
        tags.append("Fish")
    return tags


def try_tag_recipe(mealie_url: str, token: str, slug: str, tags: list[str]) -> None:
    # Mealie scraper can vary by version/site; tagging is best-effort. If this fails,
    # the import still succeeded and the log shows the warning.
    status, recipe = request_json("GET", f"{mealie_url}/api/recipes/{slug}", token)
    if status != 200 or not isinstance(recipe, dict):
        print(f"WARN could not fetch imported recipe {slug} for tagging: HTTP {status}")
        return

    current = recipe.get("tags") or []
    current_names = {t.get("name") for t in current if isinstance(t, dict)}
    for name in tags:
        if name not in current_names:
            current.append({"name": name})
    recipe["tags"] = current

    status, result = request_json("PUT", f"{mealie_url}/api/recipes/{slug}", token, recipe)
    if status not in (200, 201):
        print(f"WARN could not tag {slug}: HTTP {status} {result}")


def import_url(mealie_url: str, token: str, url: str) -> str | None:
    status, data = request_json("POST", f"{mealie_url}/api/recipes/create/url", token, {"url": url})
    if status not in (200, 201):
        print(f"FAIL {url}: HTTP {status} {data}")
        return None
    if isinstance(data, dict):
        return data.get("slug") or data.get("recipe", {}).get("slug")
    return None


def main() -> int:
    mealie_url = env("MEALIE_URL")
    token = env("MEALIE_API_TOKEN")
    max_imports = int(os.environ.get("MAX_IMPORTS_PER_RUN", DEFAULT_MAX_IMPORTS))
    url_file = Path(os.environ.get("MEALIE_RECIPE_URL_FILE", str(DEFAULT_URL_FILE)))

    candidates = read_candidates(url_file)
    already = existing_org_urls(mealie_url, token)
    imported = 0

    print(f"Weekly Mealie import: {len(candidates)} candidate URLs, {len(already)} existing source URLs")
    for url in candidates:
        if imported >= max_imports:
            break
        if normalize_url(url) in already:
            print(f"SKIP already imported: {url}")
            continue
        print(f"IMPORT {url}")
        slug = import_url(mealie_url, token, url)
        if slug:
            imported += 1
            tags = DEFAULT_TAGS + protein_tags(url)
            try_tag_recipe(mealie_url, token, slug, tags)
            print(f"OK {slug}")
            time.sleep(2)

    print(f"DONE imported={imported}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
