# Webwerk WordPress Management Suite v2.0

**🇩🇪 Deutsch** · [🇬🇧 English](README.en.md)

Eine Sammlung von Bash-Skripten zur automatisierten **Installation, Aktualisierung
und Verwaltung** vieler WordPress-Seiten — mit Fokus auf **Barrierefreiheit** für
Web-Agenturen und Entwickler:innen.

> Dies ist die kompakte deutsche Übersicht. Die **vollständige Referenz** (alle
> Optionen, Beispiele, Architektur) steht auf Englisch: **[README.en.md](README.en.md)**.

---

## Funktionen

- **Multi-Mode-Installation**: lokal (mit Git-Repo), bare (nur WordPress) oder DDEV
- **Sammel-Updates**: Core, Plugins und Themes über viele Seiten hinweg
- **Git-Integration**: Klonen und Synchronisieren von `wp-content`-Repos, Commit/Push,
  Branch-Verwaltung je Seite (`install -B`, `get branch`, `set branch NAME|all|merge`)
- **Lizenzverwaltung**: ACF Pro, WP Migrate DB Pro, Akeeba
- **Nur-Lesen-Abfragen** (`get`) und **Diagnose** (`doctor`) getrennt von Änderungen (`set`)
- **Barrierefreiheit**: das Leitthema der gesamten Suite

## Voraussetzungen

Bash 4+, WP-CLI, MySQL/MariaDB, PHP 7.4+, Git. Optional: DDEV/Docker.
Läuft unter Linux, WSL2 und macOS.

## Installation

```bash
git clone https://github.com/webwerk/ww-wpms.git
cd ww-wpms
sudo ./install.sh        # installiert nach /usr/local/bin + Shell-Completions
webwerk doctor           # Einrichtung prüfen
```

Completions für **fish**, **bash** und **zsh** liegen in `completions/` und werden
von `install.sh` automatisch eingerichtet.

## Konfiguration

Zwei Dateien:

- **`.env`** — Datenbank, WordPress, Git, lokale URL-Basis (`cp env.example .env`)
- **`~/.keys`** — Lizenzschlüssel, außerhalb des Repos (`cp keys.template ~/.keys && chmod 600 ~/.keys`)

## Befehlsgrammatik

Verb-zuerst: `webwerk VERB [MODUS] [WAS] [OPTIONEN]`

- **VERB** = `install | update | set | get | remove | doctor`
- **MODUS** = `local (Standard) | bare | ddev` — `ddev` ist ein reines Modus-Wort
  (`install ddev`, `update ddev`, …), kein eigenes Verb
- Verben und Modi akzeptieren eindeutige Abkürzungen:
  `i`→install, `u`→update, `s`→set, `g`→get, `r`→remove, `doc`→doctor;
  `l`→local, `b`→bare, `d`→ddev
- `webwerk help`, `webwerk <verb> help` und z. B. `webwerk get themes help` gehen überall

### Aufteilung nach Aufgabe

| Verb | Aufgabe |
|------|---------|
| **install** | neue Seite anlegen (local/bare/ddev) |
| **update** | Core/Plugins/Themes aktualisieren |
| **get** | **nur lesen**: Bestand/Status abfragen |
| **set** | Seiten **ändern** (Plugin, Theme, Config, Git, Benutzer …) |
| **doctor** | **Diagnose**: `config` (das Tool) oder `sites` (Seiten-Gesundheit) |
| **remove** | Seite löschen (destruktiv) |

## Häufige Befehle

```bash
# Installation (local ist Standard)
webwerk install --wp-title="Barrierefreie Website"
webwerk install ddev                      # im DDEV-Container
webwerk install -A -G arbeit              # Batch: in jedes leere Unterverzeichnis
webwerk install -G arbeit -B              # alle Branches lokal anlegen, nicht nur main

# Updates
webwerk update -a                         # alle Seiten, Pause nach jeder (x = Abbruch)
webwerk update -A                         # alle Seiten, ohne Pause/Rückfragen (= -ay)
webwerk update plugins -A                 # nur Plugins
webwerk update -ASp                       # ein Sammel-Commit + Push (nur mit -p)

# Lesen (ändert nichts)
webwerk get brief                         # kurzer Überblick je Seite
webwerk get brief --outdated              # nur Seiten mit verfügbaren Updates
webwerk get plugins                       # Plugin-Liste je Seite
webwerk get branch                        # Branches je wp-content-Repo (-l lokal / -r remote);
                                          # holt vorher die Remote-Refs, zeigt also auch
                                          # Branches, die nach dem Klonen entstanden sind
webwerk get status -a                     # ausführlich, Seite für Seite (Pause dazwischen)

# Ändern
webwerk set -s meineseite -x on           # Debug-Modus einschalten
webwerk set plugin update all             # Plugins aktualisieren
webwerk set branch live                   # ein Befehl: fetch + anlegen (folgt origin/live,
                                          # wenn dort vorhanden) + hinwechseln + push -u origin
webwerk set branch live no-push           # dasselbe, aber nur lokal
webwerk set branch all                    # alle Remote-Branches lokal anlegen (kein Wechsel)

# Diagnose
webwerk doctor                            # = doctor config: Tool-Einrichtung prüfen
webwerk doctor sites                      # je Seite OK/ERR (installiert? DB erreichbar?)

# Löschen (destruktiv)
webwerk remove -s meineseite
```

### Seitenauswahl (`-s`)

- `-s name1,name2` — direkt bestimmte Seiten wählen
- **`-s` ohne Wert** — listet die Seiten **nummeriert** auf; Auswahl per **Name oder
  Nummer** (`GMU,SBZ` oder `1,5`). Funktioniert bei `update`/`set`/`get`/`doctor sites`/`remove`
- `-a` alle Seiten (mit Pause dazwischen), `-A` alle ohne Pause

Die volle Optionsliste je Befehl: `webwerk <verb> -h` — oder die
**[englische Referenz](README.en.md)**.

### Branch-Workflow

`wp-content` ist je Seite ein Git-Repo. Die Branch-Befehle liegen bewusst unter
drei Verben: `install` richtet ein, `get` zeigt den Stand, `set` ändert ihn.

```bash
# 1. Installieren — gleich alle Branches lokal anlegen. Ein normaler Klon legt
#    nur den Default-Branch lokal an; live/staging gäbe es nur als origin/*.
webwerk install -G arbeit -B

# 2. Ansehen — holt vorher von origin, zeigt also auch Branches, die nach dem
#    Klonen entstanden sind. Legt selbst nichts an.
webwerk get branch -s meineseite

# 3. Auf einem Branch arbeiten — ein Befehl: fetch + anlegen + hinwechseln
#    + push -u origin
webwerk set -s meineseite branch live             # bei origin vorhanden -> folgt origin/live
webwerk set -s meineseite branch relaunch         # neuer Name -> vom aktuellen Branch
webwerk set -s meineseite branch relaunch no-push # dasselbe, aber nur lokal

# 4. Den Rest nachholen (ohne -B installiert oder neue Branches bei origin):
#    kein Wechsel, kein Push — du bleibst, wo du bist.
webwerk set -s meineseite branch all

# 5. Zusammenführen — pusht nie, du prüfst und pushst selbst.
webwerk set -s meineseite branch merge            # aktueller -> live (Standardziel)
webwerk set -A branch merge staging               # …über alle Seiten
```

Sicherheitsnetze bei vielen Seiten gleichzeitig:

- **`set branch NAME` pusht standardmäßig** — mit `-A`/`-a` also auf *jeder*
  gewählten Seite. `no-push` hält es lokal; ein fehlgeschlagener Push verliert
  nichts, der Branch wird trotzdem angelegt und ausgecheckt.
- **`merge` pusht nie** und lässt kein Repo halbfertig: verschmutzter
  Arbeitsbaum, detached HEAD oder fehlendes Ziel werden übersprungen, Konflikte
  abgebrochen, danach wird zurückgewechselt.
- **`get branch` ändert nichts** — der Fetch berührt nur `refs/remotes`.
- **`add` ist optional** (`branch add live` = `branch live`), aber bei mehreren
  Namen nötig — so wird ein vertipptes `merge` abgelehnt statt Branches mit dem
  Tippfehler anzulegen und zu pushen.

## Ausgabe & Barrierefreiheit

`update` zeigt je Seite eine aufgeräumte Zusammenfassung. Anzeige-Modi:
`-q` (eine Statuszeile je Seite mit Prozent), `-v` (ausführlich + Live-Ausgabe von
WP-CLI), `-B` (kompakt). Kurze, eindeutige Befehle und wenige Tastenanschläge sind
hier bewusst gewählt — das erleichtert die Bedienung erheblich.

## Lizenz

MIT.

---

**Webwerk** – WordPress für alle zugänglich machen. ♿✨

Entwickelt bei **[Pfennigparade webwerk](https://www.pfennigparade.de/webwerk)** —
dem Medienservice der Pfennigparade, der barrierefreie Websites und digitale Inhalte
erstellt; Menschen mit Körperbehinderung übernehmen Konzeption, Design, Programmierung
und Redaktion.
