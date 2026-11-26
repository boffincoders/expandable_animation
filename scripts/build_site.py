#!/usr/bin/env python3
"""Builds the static documentation website into build/site.

Each file in website/pages/ is an HTML fragment that starts with a front
matter block:

    ---
    title: Flutter Card to Fullscreen Animation
    description: One sentence used for the meta description.
    path: examples/card-to-fullscreen/
    heading: Card to fullscreen animation in Flutter
    section: examples
    schema: article
    ---
    <p>Body HTML...</p>

The fragment is wrapped in website/layout.html, written to
build/site/<path>index.html, and added to sitemap.xml. Static assets in
website/assets/ are copied as-is. Afterwards every internal link and asset
reference is checked, and the build fails on any broken one.

Usage: build_site.py [--site-url URL] [--version X.Y.Z] [--demo DIR]
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import shutil
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse

ROOT = Path(__file__).resolve().parent.parent
WEBSITE = ROOT / "website"
OUT = ROOT / "build" / "site"

FRONT_MATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)
NAV = [
    ("getting-started/", "Getting started", "getting-started"),
    ("documentation/", "Documentation", "documentation"),
    ("examples/", "Examples", "examples"),
    ("playground/", "Playground", "playground"),
]


def parse_page(path: Path) -> tuple[dict[str, str], str]:
    text = path.read_text(encoding="utf-8")
    match = FRONT_MATTER.match(text)
    if not match:
        sys.exit(f"error: {path} has no front matter")
    meta: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if line.strip():
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
    for required in ("title", "description", "path", "heading"):
        if required not in meta:
            sys.exit(f"error: {path} is missing '{required}'")
    if not 50 <= len(meta["description"]) <= 170:
        print(
            f"warning: {path.name} description is {len(meta['description'])} "
            "characters; aim for 50-170",
            file=sys.stderr,
        )
    return meta, text[match.end():]


def relative_root(page_path: str) -> str:
    depth = page_path.strip("/").count("/") + 1 if page_path.strip("/") else 0
    return "../" * depth if depth else "./"


def structured_data(meta: dict[str, str], url: str, site_url: str,
                    version: str) -> str:
    graph: list[dict[str, object]] = []
    if meta.get("schema") == "software":
        graph.append({
            "@type": "SoftwareSourceCode",
            "name": "expandable_animation",
            "description": meta["description"],
            "url": site_url,
            "codeRepository":
                "https://github.com/boffincoders/expandable_animation",
            "programmingLanguage": ["Dart", "Flutter"],
            "license": "https://opensource.org/licenses/MIT",
            "version": version,
            "runtimePlatform": "Flutter",
        })
    elif meta.get("schema") == "article":
        graph.append({
            "@type": "TechArticle",
            "headline": meta["heading"],
            "description": meta["description"],
            "url": url,
            "inLanguage": "en",
            "proficiencyLevel": "Beginner",
            "about": "Flutter animation",
        })
    crumbs = [{"name": "Home", "item": site_url}]
    parts = [p for p in meta["path"].strip("/").split("/") if p]
    for index, _ in enumerate(parts):
        sub = "/".join(parts[: index + 1]) + "/"
        name = meta["heading"] if index == len(parts) - 1 else parts[index].replace("-", " ").title()
        crumbs.append({"name": name, "item": urljoin(site_url, sub)})
    if len(crumbs) > 1:
        graph.append({
            "@type": "BreadcrumbList",
            "itemListElement": [
                {"@type": "ListItem", "position": i + 1, **crumb}
                for i, crumb in enumerate(crumbs)
            ],
        })
    if not graph:
        return ""
    payload = {"@context": "https://schema.org", "@graph": graph}
    return ('<script type="application/ld+json">'
            + json.dumps(payload, separators=(",", ":"))
            + "</script>")


def render(layout: str, meta: dict[str, str], body: str, site_url: str,
           version: str) -> str:
    page_path = meta["path"]
    is_404 = page_path == "404/"
    url = urljoin(site_url, "404.html" if is_404 else page_path)
    # The 404 page is served at arbitrary paths, so it needs absolute links.
    root = site_url if page_path == "404/" else relative_root(page_path)
    nav = []
    for href, label, section in NAV:
        current = ' aria-current="page"' if meta.get("section") == section else ""
        nav.append(f'<a href="{root}{href}"{current}>{label}</a>')
    replacements = {
        "{{TITLE}}": html.escape(meta["title"]),
        "{{DESCRIPTION}}": html.escape(meta["description"]),
        "{{HEADING}}": html.escape(meta["heading"]),
        "{{CANONICAL}}": url,
        "{{SITE_URL}}": site_url,
        "{{ROOT}}": root,
        "{{NAV}}": "\n          ".join(nav),
        "{{VERSION}}": version,
        "{{STRUCTURED_DATA}}": structured_data(meta, url, site_url, version),
        "{{OG_TYPE}}": "website" if meta.get("schema") == "software" else "article",
        "{{ROBOTS}}": '<meta name="robots" content="noindex">' if is_404 else "",
        "{{HERO_CLASS}}": "hero" if meta.get("layout") == "landing" else "page-header",
    }
    rendered = layout.replace("{{BODY}}", body)
    for key, value in replacements.items():
        rendered = rendered.replace(key, value)
    # Body fragments may use {{ROOT}} and {{VERSION}} too.
    rendered = rendered.replace("{{ROOT}}", root).replace("{{VERSION}}", version)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}", rendered)
    if leftover:
        sys.exit(f"error: unreplaced placeholders {leftover} in {page_path}")
    return rendered


class LinkCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if value and name in ("href", "src"):
                self.links.append(value)


def check_links(site: Path, site_url: str, has_demo: bool) -> list[str]:
    errors = []
    site_host = urlparse(site_url)
    for page in site.rglob("*.html"):
        if (site / "demo") in page.parents:
            continue
        collector = LinkCollector()
        collector.feed(page.read_text(encoding="utf-8"))
        for link in collector.links:
            parsed = urlparse(link)
            if parsed.scheme in ("mailto", "tel", "data", "javascript"):
                continue
            if parsed.scheme in ("http", "https"):
                if parsed.netloc != site_host.netloc or not parsed.path.startswith(site_host.path):
                    continue  # External links are not checked offline.
                target = site / parsed.path[len(site_host.path):]
            else:
                if not parsed.path:
                    continue  # Same-page anchor.
                target = (page.parent / parsed.path).resolve()
            if not has_demo and (site / "demo") in [target, *target.parents]:
                continue  # Built separately; checked when --demo is given.
            if target.is_dir() or str(target).endswith("/"):
                target = target / "index.html"
            if not target.exists():
                errors.append(f"{page.relative_to(site)} -> {link}")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--site-url",
                        default="https://boffincoders.github.io/expandable_animation/")
    parser.add_argument("--version", required=True)
    parser.add_argument("--demo", help="Flutter web build to publish at /demo/")
    args = parser.parse_args()
    site_url = args.site_url if args.site_url.endswith("/") else args.site_url + "/"

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    shutil.copytree(WEBSITE / "assets", OUT / "assets")

    layout = (WEBSITE / "layout.html").read_text(encoding="utf-8")
    today = dt.date.today().isoformat()
    sitemap_urls = []
    seen_titles: dict[str, str] = {}
    seen_descriptions: dict[str, str] = {}
    for source in sorted((WEBSITE / "pages").glob("*.html")):
        meta, body = parse_page(source)
        for seen, key in ((seen_titles, "title"), (seen_descriptions, "description")):
            if meta[key] in seen:
                sys.exit(f"error: duplicate {key} in {source.name} and {seen[meta[key]]}")
            seen[meta[key]] = source.name
        target = OUT / meta["path"] / "index.html" if meta["path"] else OUT / "index.html"
        if meta["path"] == "404/":
            target = OUT / "404.html"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render(layout, meta, body, site_url, args.version),
                          encoding="utf-8")
        if meta.get("sitemap", "yes") != "no":
            sitemap_urls.append(urljoin(site_url, meta["path"]))

    if args.demo:
        demo = Path(args.demo)
        if not (demo / "index.html").exists():
            sys.exit(f"error: no Flutter web build at {demo}")
        shutil.copytree(demo, OUT / "demo")
        sitemap_urls.append(urljoin(site_url, "demo/"))

    entries = "\n".join(
        f"  <url><loc>{html.escape(u)}</loc><lastmod>{today}</lastmod></url>"
        for u in sitemap_urls
    )
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}\n</urlset>\n",
        encoding="utf-8",
    )
    (OUT / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\n\nSitemap: {urljoin(site_url, 'sitemap.xml')}\n",
        encoding="utf-8",
    )
    # GitHub Pages: serve files as-is, without Jekyll processing.
    (OUT / ".nojekyll").write_text("", encoding="utf-8")

    errors = check_links(OUT, site_url, has_demo=bool(args.demo))
    if errors:
        print("error: broken internal links:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        sys.exit(1)
    print(f"Built {len(sitemap_urls)} pages into {OUT.relative_to(ROOT)}; "
          "all internal links resolve.")


if __name__ == "__main__":
    main()
