"""MkDocs-hooks for dokumentasjonssiden.

1. Sider med `kilde: <fil>` i front matter får innholdet fra den filen i repoet (README.md,
   README.en.md, scripts/README.md, zyxel_nr7302.yml), så teksten bare vedlikeholdes ett sted.
2. Relative lenker skrives om: lenker til filer som er egne sider peker til siden, lenker til
   andre filer i repoet (skript, .gitignore, LICENSE.md ...) peker til GitHub.
3. GitHub-varsler (> [!WARNING]) blir MkDocs-admonitions.
"""
import os
import posixpath
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GITHUB = "https://github.com/egkristi/Zyxel_NR7302"

# repo-sti -> side i docs/
PAGES = {
    "README.md": "index.md",
    "README.en.md": "en.md",
    "scripts/README.md": "skript.md",
    "zyxel_nr7302.yml": "konfigurasjon.md",
    "docs/README.md": "index.md",
}

LINK = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+)\)")
ALERT = re.compile(r"^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\n((?:>.*\n?)*)", re.M)
KINDS = {"NOTE": "note", "TIP": "tip", "IMPORTANT": "info", "WARNING": "warning", "CAUTION": "danger"}


def _rewrite_link(target, src_dir):
    if re.match(r"^[a-z]+:", target) or target.startswith("#"):
        return target
    path, _, anchor = target.partition("#")
    repo_path = posixpath.normpath(posixpath.join(src_dir, path))
    anchor = f"#{anchor}" if anchor else ""
    if repo_path in PAGES:
        return PAGES[repo_path] + anchor
    if repo_path.startswith("docs/") and repo_path.endswith(".md"):
        return repo_path[len("docs/"):] + anchor
    kind = "tree" if os.path.isdir(os.path.join(ROOT, repo_path)) else "blob"
    return f"{GITHUB}/{kind}/main/{repo_path}{anchor}"


def _alerts(md):
    def repl(m):
        body = re.sub(r"^> ?", "", m.group(2), flags=re.M).strip("\n")
        return f"!!! {KINDS[m.group(1)]}\n\n" + "\n".join(f"    {line}" for line in body.split("\n")) + "\n"
    return ALERT.sub(repl, md)


def on_page_markdown(markdown, page, config, files):
    kilde = page.meta.get("kilde")
    if kilde:
        with open(os.path.join(ROOT, kilde), encoding="utf-8") as f:
            text = f.read()
        if kilde.endswith((".yml", ".yaml")):
            markdown = f"{markdown.rstrip()}\n\n```yaml\n{text}```\n"
        else:
            markdown = text
        src_dir = posixpath.dirname(kilde)
    else:
        src_dir = "docs"
    markdown = LINK.sub(lambda m: f"[{m.group(1)}]({_rewrite_link(m.group(2), src_dir)})", markdown)
    return _alerts(markdown)
