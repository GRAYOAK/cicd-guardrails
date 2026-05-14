# cicd-guardrails

Wiederverwendbare GitHub Actions Workflows die automatisch gegen häufige CI/CD-Sicherheitsfehler prüfen.  
Grundlage: [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/).

---

## Was wird geprüft?

Skripte, Workflow-Job-IDs und `FB_CHECK_ID` folgen einheitlich der OWASP-Designation. Die **Display-Namen** der Jobs nutzen zwei visuelle Marker: ein Emoji für **Code** vs **Settings**, dann der Text `Code |` bzw. `Settings |`, dann ein **Themen-Emoji** und Kurz-ID mit Titel.

| Designation | Job-ID | Skript | Scope | Was wird erkannt |
|---|---|---|---|---|
| `CICD-SEC-01-FLOW` | `cicd-sec-01-flow` | `scripts/checks/domain/cicd_sec_01_flow.sh` | Settings | Branch-Flow-Kontrollen: PR-Pflicht, Approvals, force-push/delete Regeln |
| `CICD-SEC-03` | `cicd-sec-03` | `scripts/checks/domain/cicd_sec_03.sh` | Code | Python: verzeichnisbasierte `package_policy` (Defaults im Repo + Overlay); andere Ökosysteme: Manifeste/Lockfiles; Workflow-`uses:`-SHA-Pins; Dockerfile-Digests; `find` im Skript |
| `CICD-SEC-04` | `cicd-sec-04` | `scripts/checks/domain/cicd_sec_04.sh` | Code | `pull_request_target` Verwendung (Poisoned Pipeline Execution) |
| `CICD-SEC-05-PERMISSIONS` | `cicd-sec-05-permissions` | `scripts/checks/domain/cicd_sec_05_permissions.sh` | Code | Fehlende `permissions:` Blöcke auf Top-Level oder Job-Ebene |
| `CICD-SEC-05-BRANCH` | `cicd-sec-05-branch` | `scripts/checks/domain/cicd_sec_05_branch.sh` | Settings | Branch-Governance: Admin-Enforcement, stale reviews, code-owner policy |
| `CICD-SEC-05-RUNNER-ACCESS` | `cicd-sec-05-runner-access` | `scripts/checks/domain/cicd_sec_05_runner_access.sh` | Code | Generische self-hosted Runner Labels ohne Segmentierung |
| `CICD-SEC-06` | `cicd-sec-06` | `scripts/checks/domain/cicd_sec_06.sh` | Code | Hardcoded Secrets via gitleaks |
| `CICD-SEC-07-RUNNER-HARDENING` | `cicd-sec-07-runner-hardening` | `scripts/checks/domain/cicd_sec_07_runner_hardening.sh` | Code | `--privileged` Container und `sudo` in Workflows |
| `CICD-SEC-08` | `cicd-sec-08` | `scripts/checks/domain/cicd_sec_08.sh` | Code | Composite Actions unter `actions/` — gleiche Pin-Regeln wie Workflows in SEC-03 |

### Check-Ausgabe: Scan coverage

Jeder Check schreibt neben **Searched** / **Found** / **Remediation** einen Abschnitt **Scan coverage** (englisch), der faktisch auflistet, was ausgewertet wurde (z. B. Dateianzahl, Stichproben von Pfaden, API-Kontext ohne Secrets). Über die Umgebungsvariable **`GUARDRAILS_COVERAGE`** steuerbar: `off` (kein Abschnitt), `compact` (Standard, begrenzte Pfadliste), `full` (mehr Pfade). Optional: **`GUARDRAILS_COVERAGE_MAX_PATHS`** überschreibt die Obergrenze für Pfad-Stichproben im `compact`-Modus.

Die pro Job geschriebenen JSON-Ergebnisdateien enthalten zusätzlich **`scan_coverage_markdown`**. Der Job **Risk summary** (`scripts/aggregate_risk_summary.sh`) fügt daraus den Block **Per-check scan coverage** in die Markdown-Zusammenfassung ein. Im Modus **`full`** ist die Pfadliste weiterhin begrenzt (Standard 2000, über **`GUARDRAILS_COVERAGE_FULL_MAX_PATHS`** anpassbar), damit sehr große Monorepos stabil bleiben.

> **Migrationshinweis (Breaking Change):** Job-IDs und `skip-checks`-Tokens bleiben `cicd-sec-*`. **Display-Namen** (Scope-Emoji 🧩/⚙️, `Code |` / `Settings |`, Themen-Emoji, Text) müssen in Branch Protection exakt gematcht werden. Nach einem Workflow-Pin-Update ggf. Required-Checks anpassen. Mapping siehe Abschnitt Branch Protection.

---

## Einbindung in andere Repos

### 1. SHA des Guardrails-Repos ermitteln

```bash
git ls-remote https://github.com/YOUR_ORG/cicd-guardrails HEAD
# Output: abc123...def456  HEAD
```

### 2. Workflow im Ziel-Repo anlegen

```yaml
# .github/workflows/security.yml
name: CI/CD Security Guardrails

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  # GitHub App Token für branch-protection Reads erzeugen.
  # Voraussetzung: GitHub App mit Administration:Read installiert +
  # Secrets APP_ID und APP_PRIVATE_KEY im Repo hinterlegt.
  generate-token:
    name: 'App Token generieren'
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      token: ${{ steps.app-token.outputs.token }}
    steps:
      - uses: tibdex/github-app-token@3beb63f4bd073e61482598c45c71c1019b59b73a  # v2.1.0
        id: app-token
        with:
          app_id: ${{ secrets.APP_ID }}
          private_key: ${{ secrets.APP_PRIVATE_KEY }}

  guardrails:
    needs: generate-token
    uses: Christopher-Rust/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    #                                                                        ^^^^^
    #               Immer auf vollständigen SHA pinnen – nie @main oder @v1!
    with:
      strict: true
    secrets:
      admin-token: ${{ needs.generate-token.outputs.token }}
```

> **Ohne GitHub App:** Den `generate-token` Job weglassen und `secrets:` Block entfernen.
> Die branch-API-Checks (`cicd-sec-01-flow`, `cicd-sec-05-branch`) können ohne Admin-Token skipped oder eingeschränkt sein.
> Alle file-basierten Checks laufen normal weiter.

### 3. Branch Protection konfigurieren (PRs blockieren)

GitHub → Repo Settings → Branches → Add rule → `main`:

- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- Required status checks (Display-Namen exakt so eintragen):
  - `🧩 Code | 🚨 04 — pull request target trigger`
  - `🧩 Code | 📌 08 — Action SHA pinning`
  - `🧩 Code | 🔐 05-permissions — Workflow permissions`
  - `🧩 Code | 🔒 03 — Dependency lockfiles`
  - `🧩 Code | 🕵️ 06 — Secret scanning`
  - `🧩 Code | 🖥️ 05-runner-access — Runner access`
  - `🧩 Code | 🧱 07-runner-hardening — Runner hardening`
  - `⚙️ Settings | 🧭 01-flow — Flow control` ← nur mit Admin-Token sinnvoll
  - `⚙️ Settings | 🛂 05-branch — Branch governance` ← nur mit Admin-Token sinnvoll
- ✅ Do not allow bypassing the above settings

### 4. Migrationsmodus für bestehende Repos

Es gibt zwei komplementäre Hebel:

**Caller-seitig** über den Workflow-Input – ganze Checks abschalten oder Strictness lockern:

```yaml
jobs:
  guardrails:
    uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    with:
      strict: false
      skip-checks: 'cicd-sec-06,cicd-sec-07-runner-hardening'
```

**Repo-seitig** über `.guardrails.yml` – einzelne Checks auf `warn` oder `off` schalten, ohne den Caller anzufassen. Siehe Abschnitt _Pro-Check Severity-Override_.

### 5. Risiko-Kontext über `.guardrails.yml` steuern

Der finale Job `📊 Risk summary` liest optional eine Datei `.guardrails.yml` im Ziel-Repo
und gewichtet Findings kontextabhängig.

Referenzen im Root dieses Repos:

- `.guardrails.schema.json` (Validierungsschema für Tooling und IDEs)
- `.guardrails.example.yml` (Starter-Template)

Beispiel:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Christopher-Rust/cicd-guardrails/main/.guardrails.schema.json
context:
  visibility: public                    # public | private | internal
  software_type: open_source            # open_source | private_software
  runner_type: self_hosted              # self_hosted | github_hosted
  container_registry: public            # public | private_network
  data_sensitivity: high                # low | medium | high
  deployment_criticality: prod          # dev | prod | regulated
```

Wie die Werte einfließen:

- `visibility=public` erhöht Risiko-Gewichtung für `CICD-SEC-04`, `CICD-SEC-06`, `CICD-SEC-08`
- `software_type=open_source` gewichtet Supply-Chain/Exposure höher
- `runner_type=self_hosted` gewichtet Runner-Access- und Hardening-Themen höher
- `container_registry=public` erhöht Supply-Chain-Gewichtung (vor allem `CICD-SEC-08` und Workflow-Pins in `CICD-SEC-03`, dann `CICD-SEC-06` und `CICD-SEC-04`); `private_network` reduziert sie geringfügig
- `data_sensitivity=high` und `deployment_criticality=prod|regulated` erhöhen Priorität für Secrets, Permissions und Runner-Kontrollen

Fehlt die Datei, nutzt Guardrails konservative Defaults und schreibt das transparent ins Summary.

#### Optional: Dateiscan-Overlay (`.guardrails.file-patterns.yml`)

Built-in `find`-Ausschlüsse und Handler für `CICD-SEC-03` leben in den Skripten; Consumer-Repos **müssen** keine Kopie pflegen. Optional kann das Ziel-Repo **zusätzliche** Einträge setzen:

- `global_excludes` — weitere `find -not -path` Muster (additiv zu den Defaults)
- `validation_skip_paths` — relative Pfade, die zwar gefunden, aber **ohne** Manifest-/Lock-Policy geprüft werden (sinnvoll für reine Tooling-`pyproject.toml`-Verzeichnisse)
- `package_policy.python` — partielles Überschreiben der im Guardrails-Repo mitgelieferten Python-Standardpolicy (`scripts/config/package_policy.defaults.yml`): `triggers` (welche Dateinamen ein Verzeichnis als Python-Projekt markieren), `satisfiers` (OR-Liste erlaubter Nachweis-Dateien nebenan), `allowed_trigger_combinations` (exakte erlaubte Trigger-Mengen bei mehr als einem Trigger gleichzeitig), `hash_validators` (Zuordnung Satisfier-Dateiname zu eingebautem Validator)

Merge-Verhalten: Ohne `yq` wird die mitgelieferte Default-Datei unverändert verwendet. Mit `yq` werden `package_policy.python`-Schlüssel aus dem Overlay per Objekt-Merge über die Defaults gelegt (Arrays und Maps aus dem Overlay ersetzen die gleichnamigen Defaults vollständig). Pfade mit Leerzeichen werden beim Merge über Umgebungsvariablen geladen.

**Single source of truth (Reihenfolge):** eingebaute `find`-Ausschlüsse im Guardrails-Skript-Helfer, danach die flache Python-Default-Datei [`scripts/config/package_policy.defaults.yml`](scripts/config/package_policy.defaults.yml), zuletzt optional das Overlay im Zielrepo. Die Datei [`.guardrails.file-patterns.reference.yml`](.guardrails.file-patterns.reference.yml) im Guardrails-Repository ist **nur Dokumentation** (Handler-Tabelle, Spiegel der Built-in-Excludes, vollständiges Spiegelbild von `package_policy.python`); sie wird von den Checks **nicht** eingelesen. Wenn `yq` installiert ist, stellt `tests/test_checks.sh` sicher, dass der Block `package_policy.python` in der Referenzdatei mit der mitgelieferten Default-Datei übereinstimmt — bei Änderungen an der Default-Datei die Referenz im selben Change Set anpassen.

Schema: [`.guardrails.file-patterns.schema.json`](.guardrails.file-patterns.schema.json). Handler- und Dateizuordnung sowie das dokumentierte Default-Spiegelbild: [`.guardrails.file-patterns.reference.yml`](.guardrails.file-patterns.reference.yml). Einlesen der Overlay-Datei im gescannten Repo erfolgt mit `yq`; fehlt `yq` oder die Overlay-Datei, bleiben die eingebauten Defaults aktiv (Python-Policy aus der Default-Datei, andere Ausschlüsse wie bisher).

Beispiel für ein kleines, risikoarmes Overlay (nur Pfade von der Validierung ausnehmen, Policy nicht abschwächen):

```yaml
version: 1
validation_skip_paths:
  - "third_party/fixtures/*"
```

**Upgrades für Consumer:** siehe [`migrations/README.md`](migrations/README.md). Während der Entwicklung Snippets unter [`migrations/.unreleased/`](migrations/.unreleased/) ergänzen; beim Release werden sie zu `migrations/vX.Y.Z.md` zusammengeführt. Die [`CHANGELOG.md`](CHANGELOG.md) wird durch **release-please** aus **Conventional Commits** gepflegt — nicht manuell umschreiben, wenn die Datei das so vorsieht; sichtbare Änderungen über Commit-Messages (`feat:`, `fix:`, `feat!:` usw.) einspielen.

### 6. Pro-Check Severity-Override

Für graduelles Ausrollen kann jeder Check pro Repository auf einen anderen Modus gestellt werden, ohne den globalen `strict`-Switch des Callers zu verändern. Schlüssel ist die OWASP-Designation, Wert ein Modus:

- `fail` (Default) – Findings führen zu rotem Job.
- `warn` – Findings werden gemeldet, der Job bleibt grün; im Risk-Summary tauchen sie mit Status `WARN` auf.
- `off` – Check wird als `SKIPPED` gewertet, Job bleibt grün; bereits emittierte Annotations bleiben in den Logs.

```yaml
# .guardrails.yml
checks:
  CICD-SEC-08:
    mode: warn                # action pinning vorerst nur als Warnung
  CICD-SEC-07-RUNNER-HARDENING:
    mode: warn                # privileged container schrittweise rauspatchen
  CICD-SEC-06:
    mode: fail                # Secrets bleiben hart
```

Abgrenzung: `skip-checks` (Workflow-Input) gehört dem Caller und überspringt einen Check ganz; `mode: off` gehört dem Ziel-Repo und macht das gleiche, aber mit dokumentiertem Status im Summary. Beide Hebel sind unabhängig nutzbar.

### 7. Final Summary lesen

Die finale Ausgabe im Job `📊 Risk summary` ist auf schnelle Priorisierung optimiert:

- Executive Snapshot mit Anzahl `Critical | High | Medium`
- Hinweis, wenn Checks per `mode: warn|off` deeskaliert wurden
- Kurzlegend zu **Code** vs **Settings**
- Pro Schweregrad: Unterblöcke **Code** und **Settings** (API-Checks getrennt von Datei-Checks)
- Pro Finding immer:
  - Problem
  - Exploit path
  - Impact
  - Fix first
  - kurze Referenzlinks (z. B. `[OWASP CICD-SEC-04](...)`)

Beispiel (gekürzt):

```text
- Executive snapshot: Critical `1` | High `1` | Medium `1`
- Note: 1 check(s) ran with a per-check override (mode=warn or mode=off) and have been deescalated accordingly.

#### Critical
##### Code
- **CICD-SEC-07-RUNNER-HARDENING** — Runner hardening check
  - Status: `FAIL`
  - Problem: ...
##### Settings
- **CICD-SEC-01-FLOW** — Flow control policy check
  - Status: `FAIL`
  - Problem: ...
```

---

## Repo-Struktur

```
cicd-guardrails/
├── .github/
│   └── workflows/
│       ├── full-scan.yml                 # Reusable Orchestrator (von anderen Repos aufrufbar)
│       └── self-test.yml                 # Dogfooding: dieses Repo prüft sich selbst
│
├── scripts/
│   ├── config/
│   │   └── package_policy.defaults.yml   # Python CICD-SEC-03 Standardpolicy (Flat-YAML)
│   ├── checks/
│   │   ├── domain/                       # Fachliche Startpunkte (cicd_sec_*)
│   │   │   ├── cicd_sec_01_flow.sh
│   │   │   ├── cicd_sec_03.sh
│   │   │   ├── package/                  # Sprachmodule fuer CICD-SEC-03 (JS/Go/Rust/Ruby/PHP; Python Logik)
│   │   │   │   ├── js_ts.sh
│   │   │   │   ├── python.sh
│   │   │   │   ├── go.sh
│   │   │   │   ├── rust.sh
│   │   │   │   ├── ruby.sh
│   │   │   │   └── php.sh
│   │   │   ├── cicd_sec_04.sh
│   │   │   ├── cicd_sec_05_branch.sh
│   │   │   ├── cicd_sec_05_permissions.sh
│   │   │   ├── cicd_sec_05_runner_access.sh
│   │   │   ├── cicd_sec_06.sh
│   │   │   ├── cicd_sec_07_runner_hardening.sh
│   │   │   └── cicd_sec_08.sh
│   │   └── tech/                         # Technische Adapter (API/Parsing/CLI)
│   │       ├── github_branch_protection_api.sh
│   │       └── workflow_runner_scan.sh
│   ├── aggregate_risk_summary.sh
│   └── lib/
│       ├── config.sh                     # .guardrails.yml Reader (Context + Checks)
│       ├── feedback.sh                   # Reporting-Helper, Mode-Override
│       ├── file_patterns.sh              # find-Helfer, Overlay global_excludes / validation_skip_paths
│       ├── package_policy.sh             # Python package_policy Merge (Defaults + Overlay)
│       └── package_scan.sh               # Shared helper functions for package checks
│
└── tests/
    ├── fixtures/
    │   ├── bad-prt.yml            # Schlechtes Beispiel – soll fehlschlagen
    │   ├── bad-pinning.yml        # Schlechtes Beispiel – soll fehlschlagen
    │   └── good-workflow.yml      # Gutes Beispiel – soll bestehen
    └── test_checks.sh             # Bash-Tests
```

---

## Lokale Ausführung

```bash
# Einzelnen Check manuell gegen ein Repo ausführen
bash scripts/checks/domain/cicd_sec_04.sh                /pfad/zum/repo
bash scripts/checks/domain/cicd_sec_08.sh                /pfad/zum/repo
bash scripts/checks/domain/cicd_sec_05_permissions.sh    /pfad/zum/repo  # benötigt yq
bash scripts/checks/domain/cicd_sec_03.sh                /pfad/zum/repo
bash scripts/checks/domain/cicd_sec_05_runner_access.sh  /pfad/zum/repo
bash scripts/checks/domain/cicd_sec_07_runner_hardening.sh /pfad/zum/repo
GH_TOKEN=<dein-token> GITHUB_REPOSITORY=owner/repo bash scripts/checks/domain/cicd_sec_01_flow.sh /pfad/zum/repo
GH_TOKEN=<dein-token> GITHUB_REPOSITORY=owner/repo bash scripts/checks/domain/cicd_sec_05_branch.sh /pfad/zum/repo

# Tests ausführen
bash tests/test_checks.sh
```

### Pre-commit integration for consumer repositories

`cicd-guardrails` now publishes reusable pre-commit hook definitions via `.pre-commit-hooks.yaml`.
Consumer repositories can pin this repository to the same commit SHA used by the reusable workflow.

Example:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Christopher-Rust/cicd-guardrails
    rev: <same-40-char-sha-as-full-scan-workflow>
    hooks:
      - id: cicd-sec-04
      - id: cicd-sec-08
      - id: cicd-sec-05-permissions
      - id: cicd-sec-05-runner-access
      - id: cicd-sec-07-runner-hardening
      - id: cicd-sec-03
      - id: cicd-sec-06
        stages: [manual]
```

Local-first hooks are intentionally focused on repository-file analysis.
API-context checks (`CICD-SEC-01-FLOW`, `CICD-SEC-05-BRANCH`) remain workflow-focused and are not enabled as default pre-commit hooks.

### Modular package check architecture

`CICD-SEC-03` keeps its public designation and workflow wiring, but internally uses a dispatcher pattern.
The top-level check script orchestrates language modules with a stable interface:

- input: repository root path
- output: findings via shared reporting library
- exit semantics: `0` (pass/warn), `1` (fail), `2` (missing runtime dependency)

Current language modules:

- `scripts/checks/domain/package/js_ts.sh`
- `scripts/checks/domain/package/python.sh`
- `scripts/checks/domain/package/go.sh`
- `scripts/checks/domain/package/rust.sh`
- `scripts/checks/domain/package/ruby.sh`
- `scripts/checks/domain/package/php.sh`

This design supports repositories with one service at root and monorepos with many nested services.

---

## Dependabot aktivieren

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    labels: [dependencies, security]
```

---

## Hinweise

**gitleaks SHA:** Der `cicd-sec-06` Job lädt gitleaks herunter. Den Versions-Pin in `full-scan.yml` ggf. an die aktuelle Release ([gitleaks Releases](https://github.com/gitleaks/gitleaks/releases)) anpassen.

**GITHUB_WORKFLOW_REF:** Die Workflows parsen `GITHUB_WORKFLOW_REF` um den exakten Guardrails-SHA zu ermitteln – Skripte werden immer in der Version geladen die zum aufgerufenen Workflow passt.

**yq:** Auf GitHub-hosted Runnern vorinstalliert. Lokal: `brew install yq`. Wird sowohl von einzelnen Checks als auch vom `.guardrails.yml`-Reader genutzt; fehlt yq, fallen Werte auf konservative Defaults zurück (`mode=fail`).

**branch-basierte domain checks:** `cicd_sec_01_flow.sh` und `cicd_sec_05_branch.sh` benötigen für vollständige API-Auswertung ein Token mit Branch-Protection-Leserechten. Ohne geeigneten Token werden API-Pfade als Warnung/Skip behandelt.

**Rechte:** Alle anderen Checks brauchen nur `contents: read`. Keine Admin-Rechte erforderlich.
