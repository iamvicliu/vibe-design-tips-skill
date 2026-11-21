#!/usr/bin/env python3
"""Sync Vibe Design Tips official issues from https://vibedesign.tips/.

Stdlib-only script that:
1. Discovers all published issues from https://vibedesign.tips/zh/ and /sitemap.xml.
2. Fetches each issue's Chinese skill content from /{slug}/tip.zh.json.
3. Updates issues/<slug>.md for any new or revised tips.
4. Regenerates the index tables and issue-count ranges in SKILL.md and README.md.
"""

from __future__ import annotations

import argparse
import html as html_lib
import http.client
import json
import re
import sys
import time
import urllib.parse
from dataclasses import dataclass, field
from pathlib import Path

BASE_URL = "https://vibedesign.tips"
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)

SKILL_TABLE_START = "<!-- AUTO-SYNC:SKILL-TABLE:START -->"
SKILL_TABLE_END = "<!-- AUTO-SYNC:SKILL-TABLE:END -->"
README_TABLE_START = "<!-- AUTO-SYNC:README-TABLE:START -->"
README_TABLE_END = "<!-- AUTO-SYNC:README-TABLE:END -->"

DEFAULT_CATEGORIES = [
    "按钮与材质",
    "布局与排版",
    "交互、浮层与控件",
    "高级动效与卡片",
]


@dataclass
class IssueInfo:
    slug: str
    number: int
    issue_str: str
    title: str
    summary: str
    skill_text: str
    tags: list[str] = field(default_factory=list)
    category: str = ""
    skill_summary: str = ""
    readme_summary: str = ""


class HttpClient:
    """Stdlib keep-alive HTTP/HTTPS client with automatic reconnect and retries."""

    def __init__(self, timeout: int = 20, retries: int = 3) -> None:
        self.timeout = timeout
        self.retries = retries
        self._conns: dict[tuple[str, str], http.client.HTTPConnection] = {}

    def _get_conn(self, scheme: str, netloc: str) -> http.client.HTTPConnection:
        key = (scheme, netloc)
        conn = self._conns.get(key)
        if conn is None:
            if scheme == "https":
                conn = http.client.HTTPSConnection(netloc, timeout=self.timeout)
            elif scheme == "http":
                conn = http.client.HTTPConnection(netloc, timeout=self.timeout)
            else:
                raise ValueError(f"Unsupported URL scheme: {scheme}")
            self._conns[key] = conn
        return conn

    def _reset_conn(self, scheme: str, netloc: str) -> None:
        key = (scheme, netloc)
        conn = self._conns.pop(key, None)
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass

    def close(self) -> None:
        for conn in self._conns.values():
            try:
                conn.close()
            except Exception:
                pass
        self._conns.clear()

    def fetch_text(self, url: str) -> str:
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/json,application/xml,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Connection": "keep-alive",
        }
        current_url = url
        last_err: Exception | None = None

        for attempt in range(1, self.retries + 1):
            parsed = urllib.parse.urlsplit(current_url)
            scheme, netloc = parsed.scheme, parsed.netloc
            path = parsed.path or "/"
            if parsed.query:
                path = f"{path}?{parsed.query}"

            try:
                conn = self._get_conn(scheme, netloc)
                conn.request("GET", path, headers=headers)
                resp = conn.getresponse()
                body = resp.read()

                if resp.status in (301, 302, 303, 307, 308):
                    location = resp.getheader("Location")
                    if location:
                        current_url = urllib.parse.urljoin(current_url, location)
                        continue
                if resp.status == 200:
                    return body.decode("utf-8")
                if resp.status in (400, 404):
                    raise RuntimeError(f"HTTP {resp.status} for {current_url}")
                raise RuntimeError(f"HTTP {resp.status} for {current_url}")
            except Exception as err:
                last_err = err
                self._reset_conn(scheme, netloc)
                if "HTTP 400 " in str(err) or "HTTP 404 " in str(err):
                    raise
                if attempt < self.retries:
                    time.sleep(1.0 * attempt)

        assert last_err is not None
        raise last_err


def discover_slugs(client: HttpClient, base_url: str) -> tuple[list[str], dict[str, str], str]:
    """Discover published issue slugs from /zh/ HTML and /sitemap.xml."""
    zh_html = ""
    titles: dict[str, str] = {}
    slug_set: set[str] = set()

    try:
        zh_html = client.fetch_text(f"{base_url}/zh/")
        for m in re.finditer(r'href="/zh/(\d{3,}-[a-z0-9-]+)/"', zh_html):
            slug_set.add(m.group(1))
        card_pattern = re.compile(
            r'href="/zh/(\d{3,}-[a-z0-9-]+)/".*?<span class="card-title">(.*?)</span>',
            re.S,
        )
        for slug, raw_title in card_pattern.findall(zh_html):
            titles[slug] = html_lib.unescape(re.sub(r"<[^>]+>", "", raw_title)).strip()
    except Exception as err:
        print(f"[warn] Failed to fetch /zh/: {err}", file=sys.stderr)

    try:
        sitemap = client.fetch_text(f"{base_url}/sitemap.xml")
        for m in re.finditer(r"/zh/(\d{3,}-[a-z0-9-]+)/", sitemap):
            slug_set.add(m.group(1))
    except Exception as err:
        print(f"[warn] Failed to fetch /sitemap.xml: {err}", file=sys.stderr)

    if not slug_set:
        raise RuntimeError("Could not discover any issues from official website.")

    sorted_slugs = sorted(slug_set, key=lambda s: (int(s.split("-", 1)[0]), s))
    return sorted_slugs, titles, zh_html


def fetch_official_tags(client: HttpClient, base_url: str, zh_html: str) -> dict[str, list[str]]:
    """Best-effort extraction of official site tags from the site's i18n JS bundle."""
    if not zh_html:
        return {}
    try:
        m_zh = re.search(r'src="(/_app/zh-[^"]+\.js)"', zh_html)
        if not m_zh:
            return {}
        zh_js = client.fetch_text(f"{base_url}{m_zh.group(1)}")
        m_i18n = re.search(r'from"\./(i18n-[^"]+\.js)"', zh_js)
        if not m_i18n:
            return {}
        i18n_js = client.fetch_text(f"{base_url}/_app/{m_i18n.group(1)}")
        pattern = re.compile(
            r'slug:`(\d{3,}-[a-z0-9-]+)`.*?tags:\[([^\]]*)\]',
            re.S,
        )
        tags_map: dict[str, list[str]] = {}
        for slug, raw_tags in pattern.findall(i18n_js):
            tags_map[slug] = re.findall(r"`([^`]+)`", raw_tags)
        return tags_map
    except Exception as err:
        print(f"[warn] Best-effort tag extraction skipped: {err}", file=sys.stderr)
        return {}


def strip_frontmatter(markdown: str) -> str:
    if markdown.startswith("---\n"):
        end = markdown.find("\n---\n", 4)
        if end != -1:
            return markdown[end + 5 :].lstrip("\n")
    return markdown


def normalize_markdown(text: str) -> str:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    if not normalized.endswith("\n"):
        normalized += "\n"
    return normalized


def infer_category(slug: str, title: str, summary: str, tags: list[str]) -> str:
    tag_set = set(tags)
    if "type" in tag_set:
        return "布局与排版"
    if "components" in tag_set and "interaction" in tag_set:
        return "交互、浮层与控件"
    if "motion" in tag_set:
        return "高级动效与卡片"
    if "effects" in tag_set:
        return "按钮与材质"
    if "components" in tag_set or "interaction" in tag_set:
        return "交互、浮层与控件"

    # Keyword fallback when official tags are unavailable.
    haystack = f"{slug} {title} {summary}".lower()
    if any(k in haystack for k in ("排版", "布局", "圆角", "type", "layout", "corner", "grid", "font")):
        return "布局与排版"
    if any(k in haystack for k in ("动效", "曲线", "卡片", "滚动", "拖拽", "消失", "光环", "card", "motion", "easing", "scroll", "drag")):
        return "高级动效与卡片"
    if any(k in haystack for k in ("材质", "玻璃", "拟物", "抖色", "ascii", "glass", "button", "dither", "shader")):
        return "按钮与材质"
    return "交互、浮层与控件"


def escape_table_cell(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip()
    return cleaned.replace("|", "\\|")


def make_default_summaries(title: str, summary: str) -> tuple[str, str]:
    clean_title = escape_table_cell(title)
    clean_summary = escape_table_cell(summary).rstrip("。.")
    if clean_summary and clean_summary != clean_title:
        # Keep SKILL.md table crisp while preserving useful detail in README.md.
        if len(clean_summary) <= 44:
            skill_sum = clean_summary
        else:
            skill_sum = clean_title
        readme_sum = (
            f"{clean_title}（{clean_summary}）"
            if clean_title not in clean_summary and len(clean_title) + len(clean_summary) <= 68
            else clean_summary
        )
        return skill_sum, readme_sum
    return clean_title, clean_title


def fetch_issue(
    client: HttpClient,
    base_url: str,
    slug: str,
    homepage_title: str,
    tags: list[str],
    curated: dict,
) -> IssueInfo:
    raw = client.fetch_text(f"{base_url}/{slug}/tip.zh.json")
    data = json.loads(raw)

    skill_text = (data.get("skillText") or "").strip()
    if not skill_text and data.get("skill"):
        skill_md = client.fetch_text(f"{base_url}{data['skill']}")
        skill_text = strip_frontmatter(skill_md).strip()

    if not skill_text or not skill_text.lstrip().startswith("#"):
        raise ValueError(f"Invalid or empty skillText fetched for {slug}")

    skill_text = normalize_markdown(skill_text)
    first_heading = skill_text.splitlines()[0].lstrip("#").strip()
    title = homepage_title or first_heading or slug
    summary = (data.get("summary") or "").strip()

    issue_prefix = slug.split("-", 1)[0]
    number = int(issue_prefix)
    issue_str = f"{number:03d}"

    override = curated.get("issues", {}).get(slug, {})
    category = override.get("category") or infer_category(slug, title, summary, tags)
    default_skill_sum, default_readme_sum = make_default_summaries(title, summary)
    skill_summary = override.get("skill_summary") or default_skill_sum
    readme_summary = override.get("readme_summary") or default_readme_sum

    return IssueInfo(
        slug=slug,
        number=number,
        issue_str=issue_str,
        title=title,
        summary=summary,
        skill_text=skill_text,
        tags=tags,
        category=category,
        skill_summary=skill_summary,
        readme_summary=readme_summary,
    )


def render_skill_table(issues: list[IssueInfo], category_order: list[str]) -> str:
    grouped: dict[str, list[IssueInfo]] = {cat: [] for cat in category_order}
    for issue in issues:
        grouped.setdefault(issue.category, []).append(issue)

    lines = [
        "| 分类 | 期号与文件 | 核心主题 |",
        "| :--- | :--- | :--- |",
    ]
    for cat, items in grouped.items():
        if not items:
            continue
        items_sorted = sorted(items, key=lambda x: x.number)
        for idx, item in enumerate(items_sorted):
            cat_cell = f"**{cat}**" if idx == 0 else ""
            link = f"[`{item.slug}.md`](./issues/{item.slug}.md)"
            lines.append(f"| {cat_cell} | {link} | {item.skill_summary} |")
    return "\n".join(lines)


def render_readme_table(issues: list[IssueInfo]) -> str:
    lines = [
        "| 期数 | 主题 | 分册文件 |",
        "| :--- | :--- | :--- |",
    ]
    for item in sorted(issues, key=lambda x: x.number):
        link = f"[`{item.slug}.md`](./issues/{item.slug}.md)"
        lines.append(f"| `#{item.issue_str}` | {item.readme_summary} | {link} |")
    return "\n".join(lines)


def replace_between_markers(content: str, start_marker: str, end_marker: str, body: str) -> str:
    pattern = re.compile(
        re.escape(start_marker) + r".*?" + re.escape(end_marker),
        re.S,
    )
    if not pattern.search(content):
        raise RuntimeError(f"Markers not found: {start_marker} .. {end_marker}")
    replacement = f"{start_marker}\n{body}\n{end_marker}"
    return pattern.sub(lambda _: replacement, content, count=1)


def update_skill_md(content: str, issues: list[IssueInfo], category_order: list[str]) -> str:
    max_issue = max(i.number for i in issues)
    max_str = f"{max_issue:03d}"

    updated = re.sub(r"001～\d{3,} 期", f"001～{max_str} 期", content)
    table = render_skill_table(issues, category_order)
    updated = replace_between_markers(updated, SKILL_TABLE_START, SKILL_TABLE_END, table)
    return updated


def update_readme_md(content: str, issues: list[IssueInfo]) -> str:
    total = len(issues)
    max_issue = max(i.number for i in issues)
    max_str = f"{max_issue:03d}"

    updated = re.sub(r"001～\d{3,} 期", f"001～{max_str} 期", content)
    updated = re.sub(r"全 \d+ 期完整收录", f"全 {total} 期完整收录", updated)
    updated = re.sub(r"\d+ 篇分册索引", f"{total} 篇分册索引", updated)
    updated = re.sub(
        r"`issues/001-\*\.md` ～ `issues/\d{3,}-\*\.md`",
        f"`issues/001-*.md` ～ `issues/{max_str}-*.md`",
        updated,
    )
    table = render_readme_table(issues)
    updated = replace_between_markers(updated, README_TABLE_START, README_TABLE_END, table)
    return updated


def build_commit_message(
    max_issue_str: str,
    added: list[IssueInfo],
    updated: list[IssueInfo],
    meta_changed: list[str],
) -> str:
    parts: list[str] = []
    if added:
        parts.append("add " + ", ".join(f"#{i.issue_str}" for i in added))
    if updated:
        parts.append("update " + ", ".join(f"#{i.issue_str}" for i in updated))
    if not parts and meta_changed:
        parts.append("refresh " + ", ".join(meta_changed))

    detail = f" ({'; '.join(parts)})" if parts else ""
    subject = f"chore(sync): sync official tips to #{max_issue_str}{detail}"

    body_lines = [
        f"Synced from {BASE_URL} (total up to #{max_issue_str}).",
        "",
    ]
    if added:
        body_lines.append("Added issues:")
        for item in added:
            body_lines.append(f"- #{item.issue_str} {item.title} ({item.slug})")
        body_lines.append("")
    if updated:
        body_lines.append("Updated issues:")
        for item in updated:
            body_lines.append(f"- #{item.issue_str} {item.title} ({item.slug})")
        body_lines.append("")
    if meta_changed:
        body_lines.append("Updated index files: " + ", ".join(meta_changed))

    return subject + "\n\n" + "\n".join(body_lines).rstrip() + "\n"


def build_step_summary(
    issues: list[IssueInfo],
    added: list[IssueInfo],
    updated: list[IssueInfo],
    meta_changed: list[str],
    dry_run: bool,
) -> str:
    max_str = f"{max(i.number for i in issues):03d}"
    mode = " (dry-run)" if dry_run else ""
    lines = [
        f"### Vibe Design Tips Official Sync{mode}",
        "",
        f"- **Source**: {BASE_URL}",
        f"- **Official issues synced**: {len(issues)} (`001` ～ `{max_str}`)",
        f"- **Added**: {len(added)}",
        f"- **Updated**: {len(updated)}",
        f"- **Index files updated**: {', '.join(meta_changed) if meta_changed else 'none'}",
    ]
    if added:
        lines.append("")
        lines.append("#### Added Issues")
        for item in added:
            lines.append(f"- `#{item.issue_str}` **{item.title}** (`issues/{item.slug}.md`)")
    if updated:
        lines.append("")
        lines.append("#### Updated Issues")
        for item in updated:
            lines.append(f"- `#{item.issue_str}` **{item.title}** (`issues/{item.slug}.md`)")
    if not added and not updated and not meta_changed:
        lines.append("")
        lines.append("Already up to date with official site.")
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync Vibe Design Tips official issues.")
    parser.add_argument("--base-url", default=BASE_URL, help="Official site base URL.")
    parser.add_argument("--timeout", type=int, default=20, help="HTTP timeout in seconds.")
    parser.add_argument("--dry-run", action="store_true", help="Check changes without writing files.")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit with code 2 if repository is out of sync (implies --dry-run).",
    )
    parser.add_argument(
        "--allow-shrink",
        action="store_true",
        help="Allow fewer discovered issues than currently stored locally.",
    )
    parser.add_argument("--summary-file", help="Optional file path to append Markdown summary.")
    parser.add_argument("--commit-msg-file", help="Optional file path to write commit message.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dry_run = args.dry_run or args.check

    repo_root = Path(__file__).resolve().parent.parent
    issues_dir = repo_root / "issues"
    skill_path = repo_root / "SKILL.md"
    readme_path = repo_root / "README.md"
    curated_path = repo_root / "scripts" / "curated_meta.json"

    curated = json.loads(curated_path.read_text(encoding="utf-8")) if curated_path.exists() else {}
    category_order = curated.get("categories") or DEFAULT_CATEGORIES

    local_issue_files = sorted(issues_dir.glob("*.md"))
    client = HttpClient(timeout=args.timeout)
    try:
        slugs, homepage_titles, zh_html = discover_slugs(client, args.base_url)

        if len(slugs) < len(local_issue_files) and not args.allow_shrink:
            raise RuntimeError(
                f"Safety abort: discovered {len(slugs)} issues, fewer than {len(local_issue_files)} "
                f"local files. Pass --allow-shrink to override."
            )

        tags_map = fetch_official_tags(client, args.base_url, zh_html)

        issues: list[IssueInfo] = []
        for slug in slugs:
            info = fetch_issue(
                client=client,
                base_url=args.base_url,
                slug=slug,
                homepage_title=homepage_titles.get(slug, ""),
                tags=tags_map.get(slug, []),
                curated=curated,
            )
            issues.append(info)
    finally:
        client.close()

    added: list[IssueInfo] = []
    updated: list[IssueInfo] = []

    issues_dir.mkdir(parents=True, exist_ok=True)
    for item in issues:
        target = issues_dir / f"{item.slug}.md"
        if not target.exists():
            added.append(item)
            if not dry_run:
                target.write_text(item.skill_text, encoding="utf-8")
        else:
            existing = target.read_text(encoding="utf-8")
            if existing != item.skill_text:
                updated.append(item)
                if not dry_run:
                    target.write_text(item.skill_text, encoding="utf-8")

    meta_changed: list[str] = []

    skill_old = skill_path.read_text(encoding="utf-8")
    skill_new = update_skill_md(skill_old, issues, category_order)
    if skill_new != skill_old:
        meta_changed.append("SKILL.md")
        if not dry_run:
            skill_path.write_text(skill_new, encoding="utf-8")

    readme_old = readme_path.read_text(encoding="utf-8")
    readme_new = update_readme_md(readme_old, issues)
    if readme_new != readme_old:
        meta_changed.append("README.md")
        if not dry_run:
            readme_path.write_text(readme_new, encoding="utf-8")

    summary_md = build_step_summary(issues, added, updated, meta_changed, dry_run)
    print(summary_md)

    if args.summary_file:
        summary_path = Path(args.summary_file)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        with summary_path.open("a", encoding="utf-8") as fh:
            fh.write(summary_md)

    has_changes = bool(added or updated or meta_changed)
    if args.commit_msg_file and has_changes:
        max_str = f"{max(i.number for i in issues):03d}"
        msg = build_commit_message(max_str, added, updated, meta_changed)
        Path(args.commit_msg_file).write_text(msg, encoding="utf-8")

    if args.check and has_changes:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
