"""MkDocs-hooks for dokumentasjonssiden.

1. Sider med `kilde: <fil>` i front matter henter innhold fra den filen i repoet, så teksten
   bare vedlikeholdes ett sted:
   - uten markører: hele filen (scripts/README.md)
   - med markører i sidens tekst: bare de navngitte seksjonene, satt inn der markøren står
       <!-- kilde: innledning -->          alt før første ##-overskrift
       <!-- kilde: Hva du oppnår -->       ##-seksjonen med den overskriften
       <!-- kilde: Fasene | innhold -->    seksjonen uten overskriften, underoverskrifter
                                             løftet ett nivå
   - yml-fil: legges sammenfoldet nederst på siden
2. Relative lenker skrives om: lenker til filer som er egne sider peker til siden, lenker til
   andre filer i repoet (skript, .gitignore, LICENSE.md ...) peker til GitHub.
3. GitHub-varsler (> [!WARNING]) blir MkDocs-admonitions.
"""
import os
import posixpath
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GITHUB = "https://github.com/egkristi/Zyxel_NR7302"

# repo-sti -> side i docs/. Engelske sider lenkes uten .en: i18n-pluginen peker lenken til
# samme språk som siden den står på.
PAGES = {
    "README.md": "index.md",
    "README.en.md": "index.md",
    "scripts/README.md": "skript.md",
    "scripts/README.en.md": "skript.md",
    "zyxel_nr7302.yml": "konfigurasjon.md",
    "docs/README.md": "index.md",
    "docs/README.en.md": "index.md",
}
# Ankre i README som havner på en annen side enn forsiden.
ANCHOR_PAGES = {"slå-på-adb": "veiledning.md", "enable-adb": "veiledning.md"}
# Språklinjen øverst i dokumentene («🇳🇴 Norsk · [🇬🇧 English](…)»): siden har egen språkvelger.
LANG_LINE = re.compile(r"^.*🇳🇴.*🇬🇧.*\n\n?", re.M)
MARKER = re.compile(r"^<!-- kilde: (.+?)(?: \| (innhold))? -->$", re.M)

LINK = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+)\)")
ALERT = re.compile(r"^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\n((?:>.*\n?)*)", re.M)
KINDS = {"NOTE": "note", "TIP": "tip", "IMPORTANT": "info", "WARNING": "warning", "CAUTION": "danger"}
TITLES = {"nb": {"NOTE": "Merk", "TIP": "Tips", "IMPORTANT": "Viktig", "WARNING": "Advarsel", "CAUTION": "Forsiktig"},
          "en": {"NOTE": "Note", "TIP": "Tip", "IMPORTANT": "Important", "WARNING": "Warning", "CAUTION": "Caution"}}
YML_TITLE = {"nb": "Hele filen: zyxel_nr7302.yml", "en": "The whole file: zyxel_nr7302.yml"}


def _rewrite_link(target, src_dir):
    if re.match(r"^[a-z]+:", target) or target.startswith("#"):
        return target
    path, _, anchor = target.partition("#")
    repo_path = posixpath.normpath(posixpath.join(src_dir, path))
    if repo_path in PAGES:
        page = ANCHOR_PAGES.get(anchor, PAGES[repo_path])
        return page + (f"#{anchor}" if anchor else "")
    anchor = f"#{anchor}" if anchor else ""
    if repo_path.startswith("docs/") and repo_path.endswith(".md"):
        return repo_path[len("docs/"):].replace(".en.md", ".md") + anchor
    kind = "tree" if os.path.isdir(os.path.join(ROOT, repo_path)) else "blob"
    return f"{GITHUB}/{kind}/main/{repo_path}{anchor}"


def _sections(text):
    """{"innledning": ..., "<##-overskrift>": (overskriftslinje, innhold)} – kodeblokker hoppes over."""
    out, current, heading, lines, fence = {}, "innledning", "", [], False
    for line in text.splitlines(keepends=True):
        if line.startswith("```"):
            fence = not fence
        if not fence and line.startswith("## "):
            out[current] = (heading, "".join(lines))
            current, heading, lines = line[3:].strip().strip("`"), line, []
            continue
        lines.append(line)
    out[current] = (heading, "".join(lines))
    return out


def _promote(md):
    fence, out = False, []
    for line in md.splitlines(keepends=True):
        if line.startswith("```"):
            fence = not fence
        out.append(line[1:] if not fence and re.match(r"^#{3,6} ", line) else line)
    return "".join(out)


def _alerts(md, lang):
    def repl(m):
        body = re.sub(r"^> ?", "", m.group(2), flags=re.M).strip("\n")
        return f'!!! {KINDS[m.group(1)]} "{TITLES[lang][m.group(1)]}"\n\n' + "\n".join(f"    {line}" for line in body.split("\n")) + "\n"
    return ALERT.sub(repl, md)


def on_page_markdown(markdown, page, config, files):
    kilde = page.meta.get("kilde")
    src_dir = "docs"
    lang = "en" if page.file.src_uri.endswith(".en.md") else "nb"
    if kilde:
        with open(os.path.join(ROOT, kilde), encoding="utf-8") as f:
            text = f.read()
        src_dir = posixpath.dirname(kilde)
        if kilde.endswith((".yml", ".yaml")):
            body = "".join(f"    {line}" if line.strip() else line for line in f"```yaml\n{text}```\n".splitlines(True))
            markdown = f'{markdown.rstrip()}\n\n??? example "{YML_TITLE[lang]}"\n\n{body}'
        elif MARKER.search(markdown):
            sections = _sections(text)

            def insert(m):
                name, only_body = m.group(1), m.group(2)
                if name not in sections:
                    raise KeyError(f"{page.file.src_uri}: fant ikke seksjonen {name!r} i {kilde}")
                heading, body = sections[name]
                return _promote(body).strip() if only_body else (heading + body).strip()

            markdown = MARKER.sub(insert, markdown)
        else:
            markdown = text
    markdown = LANG_LINE.sub("", markdown, count=1)
    markdown = LINK.sub(lambda m: f"[{m.group(1)}]({_rewrite_link(m.group(2), src_dir)})", markdown)
    return _alerts(markdown, lang)
