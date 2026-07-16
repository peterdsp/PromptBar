#!/usr/bin/env python3

"""Update a repository-owned star history chart from GitHub metadata."""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


API_VERSION = "2022-11-28"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True, help="Repository in owner/name form")
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def parse_github_date(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def format_github_date(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def fetch_repository(repository: str, token: str | None) -> dict[str, Any]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "PromptBar-star-history",
        "X-GitHub-Api-Version": API_VERSION,
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}",
        headers=headers,
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API returned HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Could not reach the GitHub API: {error.reason}") from error


def load_history(path: Path, repository: str) -> dict[str, Any]:
    history = json.loads(path.read_text(encoding="utf-8"))
    if history.get("repository") != repository:
        raise ValueError(f"History belongs to {history.get('repository')}, not {repository}")
    if not isinstance(history.get("points"), list):
        raise ValueError("History points are missing")
    return history


def update_history(history: dict[str, Any], star_count: int) -> bool:
    points = history["points"]
    previous_count = points[-1]["count"] if points else 0
    if previous_count == star_count:
        return False

    points.append(
        {
            "date": format_github_date(datetime.now(timezone.utc)),
            "count": star_count,
        }
    )
    return True


def serialize_history(history: dict[str, Any]) -> str:
    points = history["points"]
    serialized_points = [
        f"    {json.dumps(point)}{',' if index < len(points) - 1 else ''}"
        for index, point in enumerate(points)
    ]
    joined_points = "\n".join(serialized_points)
    return (
        "{\n"
        f'  "repository": {json.dumps(history["repository"])},\n'
        f'  "created_at": {json.dumps(history["created_at"])},\n'
        '  "points": [\n'
        f"{joined_points}\n"
        "  ]\n"
        "}\n"
    )


def nice_ceiling(value: int) -> int:
    if value <= 5:
        return 5

    magnitude = 10 ** math.floor(math.log10(value))
    normalized = value / magnitude
    step = 1 if normalized <= 1 else 2 if normalized <= 2 else 5 if normalized <= 5 else 10
    return step * magnitude


def chart_svg(history: dict[str, Any]) -> str:
    repository = history["repository"]
    created_at = parse_github_date(history["created_at"])
    history_points = [
        (parse_github_date(point["date"]), int(point["count"]))
        for point in history["points"]
    ]

    width = 800
    height = 420
    left = 68
    right = 28
    top = 82
    bottom = 58
    plot_width = width - left - right
    plot_height = height - top - bottom

    end_at = history_points[-1][0] if history_points else created_at
    if end_at <= created_at:
        end_at = created_at.replace(year=created_at.year + 1)

    time_span = (end_at - created_at).total_seconds()
    star_count = history_points[-1][1] if history_points else 0
    maximum_count = max((count for _, count in history_points), default=0)
    y_max = nice_ceiling(max(maximum_count, 1))

    def x_position(date: datetime) -> float:
        elapsed = (date - created_at).total_seconds()
        return left + plot_width * max(0, min(1, elapsed / time_span))

    def y_position(count: int) -> float:
        return top + plot_height * (1 - count / y_max)

    polyline_points = [(left, y_position(0))]
    previous_count = 0
    for date, count in history_points:
        x = x_position(date)
        polyline_points.append((x, y_position(previous_count)))
        polyline_points.append((x, y_position(count)))
        previous_count = count
    polyline_points.append((left + plot_width, y_position(previous_count)))
    polyline = " ".join(f"{x:.2f},{y:.2f}" for x, y in polyline_points)

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

    latest_label = history_points[-1][0].strftime("%d %b %Y") if history_points else "No stars yet"
    title = repository.split("/", maxsplit=1)[-1]

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title description">
  <title id="title">{title} star history</title>
  <desc id="description">{star_count} GitHub stars through {latest_label}.</desc>
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
  <text x="{left}" y="60" class="subtitle">{star_count} stars, refreshed daily from the GitHub API</text>
  {"".join(y_ticks)}
  {"".join(x_ticks)}
  <polygon class="area" points="{polyline} {left + plot_width},{top + plot_height} {left},{top + plot_height}"/>
  <polyline class="line" points="{polyline}"/>
</svg>
"""


def main() -> int:
    args = parse_args()

    try:
        metadata = fetch_repository(args.repository, os.environ.get("GITHUB_TOKEN"))
        history = load_history(args.data, args.repository)
        changed = update_history(history, int(metadata["stargazers_count"]))
        svg = chart_svg(history)

        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(svg, encoding="utf-8")
        if changed:
            args.data.write_text(serialize_history(history), encoding="utf-8")
    except (KeyError, OSError, RuntimeError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1

    print(f"Generated {args.output} with {metadata['stargazers_count']} stars")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
