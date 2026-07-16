#!/usr/bin/env python3

"""Generate a self-contained SVG chart from GitHub stargazer timestamps."""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


API_VERSION = "2022-11-28"
STAR_MEDIA_TYPE = "application/vnd.github.star+json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True, help="Repository in owner/name form")
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def github_request(url: str, token: str, accept: str) -> tuple[Any, dict[str, str]]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": accept,
            "Authorization": f"Bearer {token}",
            "User-Agent": "PromptBar-star-history",
            "X-GitHub-Api-Version": API_VERSION,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response), dict(response.headers.items())
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API returned HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Could not reach the GitHub API: {error.reason}") from error


def next_link(link_header: str | None) -> str | None:
    if not link_header:
        return None

    for section in link_header.split(","):
        match = re.match(r'\s*<([^>]+)>;\s*rel="([^"]+)"', section)
        if match and match.group(2) == "next":
            return match.group(1)

    return None


def fetch_star_dates(repository: str, token: str) -> tuple[datetime, list[datetime]]:
    metadata_url = f"https://api.github.com/repos/{repository}"
    metadata, _ = github_request(metadata_url, token, "application/vnd.github+json")
    created_at = parse_github_date(metadata["created_at"])

    stars: list[datetime] = []
    page_url: str | None = (
        f"https://api.github.com/repos/{repository}/stargazers?per_page=100"
    )

    while page_url:
        page, headers = github_request(page_url, token, STAR_MEDIA_TYPE)
        stars.extend(parse_github_date(item["starred_at"]) for item in page)
        page_url = next_link(headers.get("Link"))

    stars.sort()
    return created_at, stars


def parse_github_date(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def nice_ceiling(value: int) -> int:
    if value <= 5:
        return 5

    magnitude = 10 ** math.floor(math.log10(value))
    normalized = value / magnitude
    step = 1 if normalized <= 1 else 2 if normalized <= 2 else 5 if normalized <= 5 else 10
    return step * magnitude


def chart_svg(repository: str, created_at: datetime, stars: list[datetime]) -> str:
    width = 800
    height = 420
    left = 68
    right = 28
    top = 82
    bottom = 58
    plot_width = width - left - right
    plot_height = height - top - bottom

    end_at = stars[-1] if stars else created_at
    if end_at <= created_at:
        end_at = created_at.replace(year=created_at.year + 1)

    time_span = (end_at - created_at).total_seconds()
    y_max = nice_ceiling(max(len(stars), 1))

    def x_position(date: datetime) -> float:
        elapsed = (date - created_at).total_seconds()
        return left + plot_width * max(0, min(1, elapsed / time_span))

    def y_position(count: int) -> float:
        return top + plot_height * (1 - count / y_max)

    points = [(left, y_position(0))]
    for index, star_date in enumerate(stars, start=1):
        x = x_position(star_date)
        points.append((x, y_position(index - 1)))
        points.append((x, y_position(index)))
    points.append((left + plot_width, y_position(len(stars))))
    polyline = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)

    y_ticks = []
    for index in range(6):
        count = round(y_max * index / 5)
        y = y_position(count)
        y_ticks.append(
            f'<line x1="{left}" y1="{y:.2f}" x2="{left + plot_width}" '
            f'y2="{y:.2f}" class="grid"/>'
            f'<text x="{left - 12}" y="{y + 5:.2f}" text-anchor="end" '
            f'class="axis">{count}</text>'
        )

    x_ticks = []
    for index in range(5):
        fraction = index / 4
        timestamp = created_at.timestamp() + time_span * fraction
        date = datetime.fromtimestamp(timestamp, tz=timezone.utc)
        x = left + plot_width * fraction
        anchor = "start" if index == 0 else "end" if index == 4 else "middle"
        x_ticks.append(
            f'<line x1="{x:.2f}" y1="{top}" x2="{x:.2f}" '
            f'y2="{top + plot_height}" class="grid"/>'
            f'<text x="{x:.2f}" y="{top + plot_height + 30}" '
            f'text-anchor="{anchor}" class="axis">{date.strftime("%b %Y")}</text>'
        )

    latest_label = stars[-1].strftime("%d %b %Y") if stars else "No stars yet"
    title = repository.split("/", maxsplit=1)[-1]

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title description">
  <title id="title">{title} star history</title>
  <desc id="description">{len(stars)} GitHub stars through {latest_label}.</desc>
  <style>
    .background {{ fill: #ffffff; }}
    .title {{ fill: #111827; font: 700 22px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .subtitle {{ fill: #6b7280; font: 14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .axis {{ fill: #6b7280; font: 12px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .grid {{ stroke: #e5e7eb; stroke-width: 1; }}
    .line {{ fill: none; stroke: #f59e0b; stroke-linecap: round; stroke-linejoin: round; stroke-width: 3; }}
    .area {{ fill: url(#starGradient); }}
  </style>
  <defs>
    <linearGradient id="starGradient" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#fbbf24" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#fbbf24" stop-opacity="0.02"/>
    </linearGradient>
  </defs>
  <rect class="background" width="{width}" height="{height}" rx="12"/>
  <text x="{left}" y="36" class="title">{title} star history</text>
  <text x="{left}" y="60" class="subtitle">{len(stars)} stars, refreshed daily from the GitHub API</text>
  {"".join(y_ticks)}
  {"".join(x_ticks)}
  <polygon class="area" points="{polyline} {left + plot_width},{top + plot_height} {left},{top + plot_height}"/>
  <polyline class="line" points="{polyline}"/>
</svg>
"""


def main() -> int:
    args = parse_args()
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("GITHUB_TOKEN is required", file=sys.stderr)
        return 1

    try:
        created_at, stars = fetch_star_dates(args.repository, token)
        svg = chart_svg(args.repository, created_at, stars)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(svg, encoding="utf-8")
    except (KeyError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    print(f"Generated {args.output} with {len(stars)} stars")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
