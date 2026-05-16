# cicd-guardrails

**Inhalt:** [Über dieses Repository](#über-dieses-repository) · [Quick Start](#quick-start) · [Was wird geprüft?](#was-wird-geprüft) · [Einbindung in andere Repos](#einbindung-in-andere-repos) · [Repo-Struktur](#repo-struktur) · [Entwicklung an diesem Repository](#entwicklung-an-diesem-repository) · [Dependabot aktivieren](#dependabot-aktivieren) · [Hinweise](#hinweise)

---

## Über dieses Repository

Dieses Repository liefert wiederverwendbare Sicherheitsprüfungen für CI/CD-Pipelines — als GitHub Actions Workflow, als pre-commit Hooks und als ausführbare Shell-Skripte. Die Checks orientieren sich an den [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/).

Die **Implementierung** (Skripte, Workflow-Definitionen, Hook-Metadaten) liegt ausschließlich hier in `cicd-guardrails`. **Geprüft** wird immer ein **Ziel-Repository** — eure Anwendung, euer Service oder euer Monorepo. Ihr bindet Guardrails ein und pinnt eine feste Version; ihr kopiert die Check-Skripte nicht ins Ziel-Repo.

---

## Quick Start

> **Version pinnen (essentiell):** Check-Code und Workflow-Definitionen stammen **immer** aus diesem Repository — nicht aus dem Ziel-Repo kopieren. Für **jede** Nutzung (CI, pre-commit, lokale Skripte aus einem Clone) dieselbe **40-Zeichen-Commit-SHA** verwenden; **nie** `@main`, `@master` oder bewegliche Tags als einzige Referenz. **CI** und **pre-commit** im Ziel-Repo sollten denselben `rev` bzw. `@SHA` teilen, damit lokal und in der Pipeline dasselbe Verhalten gilt.
>
> SHA ermitteln (Platzhalter `YOUR_ORG` anpassen):
>
> ```bash
> git ls-remote https://github.com/YOUR_ORG/cicd-guardrails HEAD
> # Output: abc123...def456  HEAD
> ```
>
> Nach einem Release: [`migrations/README.md`](migrations/README.md) und Release-Assets lesen. Referenz-Ziel-Repos: [`cicd-demo-well`](https://github.com/Christopher-Rust/cicd-demo-well) (compliant) und [`cicd-demo-errors`](https://github.com/Christopher-Rust/cicd-demo-errors) (negative Fixtures) — dort `security.yml` und `.pre-commit-config.yaml` ohne festen SHA in dieser Doku; immer Platzhalter `<SHA>` durch euren Pin ersetzen.
>
> **Geprüft wird euer Ziel-Repository; geliefert wird die gepinnte Version von hier.**

### Lokaler Check

**Voraussetzungen:** `bash`; `yq` empfohlen (mehrere Checks und `.guardrails.yml`); optional `gitleaks` für `CICD-SEC-06`; API-Checks (`CICD-SEC-01-FLOW`, `CICD-SEC-05-BRANCH`) benötigen `GH_TOKEN` und `GITHUB_REPOSITORY`.

1. Dieses Repository klonen und auf **dieselbe SHA** wie in CI/pre-commit auschecken: `git checkout <SHA>`.
2. Einzelne Checks gegen das **Ziel-Repo** ausführen (Pfad = Repository-Root des Ziels):

```bash
bash scripts/checks/domain/cicd_sec_04.sh                 /pfad/zum/ziel-repo
bash scripts/checks/domain/cicd_sec_08.sh                 /pfad/zum/ziel-repo
bash scripts/checks/domain/cicd_sec_05_permissions.sh     /pfad/zum/ziel-repo
bash scripts/checks/domain/cicd_sec_03.sh                 /pfad/zum/ziel-repo
bash scripts/checks/domain/cicd_sec_05_runner_access.sh   /pfad/zum/ziel-repo
bash scripts/checks/domain/cicd_sec_07_runner_hardening.sh /pfad/zum/ziel-repo
GH_TOKEN=<dein-token> GITHUB_REPOSITORY=owner/repo \
  bash scripts/checks/domain/cicd_sec_01_flow.sh /pfad/zum/ziel-repo
GH_TOKEN=<dein-token> GITHUB_REPOSITORY=owner/repo \
  bash scripts/checks/domain/cicd_sec_05_branch.sh /pfad/zum/ziel-repo
```

**Maintainer** (Änderungen an Guardrails selbst): Regressionstests im Clone — siehe [Entwicklung an diesem Repository](#entwicklung-an-diesem-repository).

### Pre-commit Hook

Im **Ziel-Repo** eine `.pre-commit-config.yaml` anlegen. Hook-Definitionen kommen aus [`.pre-commit-hooks.yaml`](.pre-commit-hooks.yaml) dieses Repos; `rev` muss die **gleiche SHA** wie der CI-Workflow sein.

```yaml
# .pre-commit-config.yaml (im Ziel-Repo)
repos:
  - repo: https://github.com/YOUR_ORG/cicd-guardrails
    rev: <SHA>   # dieselbe 40-Zeichen-SHA wie full-scan.yml@<SHA>
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

Die Hooks analysieren Dateien im Ziel-Repo (pre-commit setzt das Arbeitsverzeichnis auf `.`). API-Kontext-Checks (`CICD-SEC-01-FLOW`, `CICD-SEC-05-BRANCH`) sind bewusst **nicht** als Standard-Hooks vorgesehen — dafür CI mit optionalem Admin-Token.

Vollständiges Beispiel: [cicd-demo-well `.pre-commit-config.yaml`](https://github.com/Christopher-Rust/cicd-demo-well/blob/main/.pre-commit-config.yaml).

### CI-Check (GitHub Actions)

Im **Ziel-Repo** `.github/workflows/security.yml` (Minimalvariante ohne GitHub App):

```yaml
name: CI/CD Security Guardrails

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  guardrails:
    uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    with:
      strict: true
```

Ohne Admin-Token laufen alle dateibasierten Checks; API-Checks (`cicd-sec-01-flow`, `cicd-sec-05-branch`) können eingeschränkt oder übersprungen sein.

Referenz im Ziel-Repo: [cicd-demo-well `security.yml`](https://github.com/Christopher-Rust/cicd-demo-well/blob/main/.github/workflows/security.yml).

Vollständiges Setup (GitHub App, Branch Protection, `skip-checks`, `.guardrails.yml`): Abschnitt [Einbindung in andere Repos](#einbindung-in-andere-repos).

---

**Als Nächstes:** [Was wird geprüft?](#was-wird-geprüft) · [Einbindung in andere Repos](#einbindung-in-andere-repos)

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

> **Migrationshinweis (Breaking Change):** Job-IDs und `skip-checks`-Tokens bleiben `cicd-sec-*`. **Display-Namen** (Scope-Emoji 🧩/⚙️, `Code |` / `Settings |`, Themen-Emoji, Text) müssen in Branch Protection exakt gematcht werden. Nach einem Workflow-Pin-Update ggf. Required-Checks anpassen. Mapping siehe Abschnitt [Branch Protection konfigurieren](#branch-protection-konfigurieren-prs-blockieren).

---

## Einbindung in andere Repos

SHA ermitteln, Minimal-Workflow und pre-commit-Setup: [Quick Start](#quick-start). Die folgenden Abschnitte beschreiben das vollständige Rollout im **Ziel-Repo**.

### Workflow mit Admin-Token (optional)

Für vollständige API-Checks (`cicd-sec-01-flow`, `cicd-sec-05-branch`) im Ziel-Repo eine GitHub App mit `Administration: Read` nutzen und ein kurzlebiges Token an den reusable Workflow übergeben:

```yaml
# .github/workflows/security.yml (im Ziel-Repo)
name: CI/CD Security Guardrails

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  generate-token:
    name: 'App Token generieren'
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      token: ${{ steps.app-token.outputs.token }}
    steps:
      - uses: actions/create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1  # v3.2.0
        id: app-token
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}

  guardrails:
    needs: generate-token
    uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    with:
      strict: true
    secrets:
      admin-token: ${{ needs.generate-token.outputs.token }}
```

> **Ohne GitHub App:** Den `generate-token` Job weglassen und den `secrets:` Block entfernen — wie im [Quick Start](#ci-check-github-actions). Die branch-API-Checks können ohne Admin-Token skipped oder eingeschränkt sein; alle dateibasierten Checks laufen normal weiter.

### Branch Protection konfigurieren (PRs blockieren)

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

### Migrationsmodus für bestehende Repos

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

### Risiko-Kontext über `.guardrails.yml` steuern

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

#### Release-Workflow: GitHub App (Maintainer)

Der Workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) nutzt **release-please** mit einer org-weiten GitHub App, weil `GITHUB_TOKEN` in der Organisation keine Release-PRs erstellen darf.

Voraussetzungen:

1. **GitHub App** (org-weit, nur für Releases in diesem Repo) mit Repository-Permissions:
   - **Contents**: Read and write
   - **Pull requests**: Read and write
   - **Issues**: Read and write
2. App auf **cicd-guardrails** installieren.
3. Org-Secrets (für dieses Repo sichtbar):
   - **`APP_ID`** — numerische App-ID
   - **`APP_PRIVATE_KEY`** — vollständiger PEM-Inhalt des Private Keys

Der Job `assemble-migration` pusht nach einem Release ggf. Migration-Notes auf `main`; bei Branch Protection den App-Bot in die Bypass-Liste aufnehmen.

Der Job `notify-demo-repos` nutzt eine **separate** App (`GUARDRAILS_CONSUMER_DISPATCH_APP_*`) — siehe unten.

#### Demo-Repos: automatischer Pin-Bump nach Release

Die Fixture-Repositories [`cicd-demo-errors`](https://github.com/Christopher-Rust/cicd-demo-errors) und [`cicd-demo-well`](https://github.com/Christopher-Rust/cicd-demo-well) können nach jedem erfolgreichen Release automatisch ein `repository_dispatch`-Ereignis erhalten und daraufhin einen PR öffnen, der `security.yml` und `.pre-commit-config.yaml` auf den **Release-Tag-Commit-SHA** hebt.

Voraussetzungen:

1. In beiden Demo-Repos existiert der Workflow [`.github/workflows/guardrails-release-bump.yml`](.github/workflows/guardrails-release-bump.yml) (löst nur auf `guardrails-release` aus).
2. Eine **GitHub App** (neu oder bestehend) mit Zugriff auf beide Demo-Repos:
   - Unter *GitHub App settings* → **Permissions & events** → **Repository permissions** → **Contents**: *Read and write* (für `repository_dispatch` auf dem Ziel-Repo).
   - App auf **cicd-demo-errors** und **cicd-demo-well** installieren (*Install App* → nur diese beiden Repos auswählen). Die App muss nicht auf **cicd-guardrails** installiert sein; der Release-Workflow nutzt nur App-ID und Private Key, um ein Installation-Token für die Demo-Installation zu minten.
3. Im **cicd-guardrails**-Repository unter *Settings* → *Secrets and variables* → *Actions* zwei Secrets anlegen:
   - **`GUARDRAILS_CONSUMER_DISPATCH_APP_ID`** — numerische App-ID (Profilseite der App).
   - **`GUARDRAILS_CONSUMER_DISPATCH_APP_PRIVATE_KEY`** — vollständiger PEM-Inhalt des generierten Private Keys (einschließlich `BEGIN`/`END`-Zeilen).

Ohne diese beiden Secrets bleibt der Release-Workflow grün; der Job `notify-demo-repos` überspringt das Dispatch mit Loghinweis. Sind die Secrets gesetzt und das Minting des Tokens schlägt fehl (falscher Key, App nicht auf den Demos installiert), wird ebenfalls übersprungen. Schlägt das Minting zu, aber **alle** Dispatch-Aufrufe fehl, wird der Job rot (Konfigurationsfehler).

**Benachrichtigung:** GitHub benachrichtigt Abonnenten wie bei jedem anderen neuen PR (Watch → *Pull requests* oder *Participating*). Zusätzliche Webhooks sind nicht vorgesehen.

### Pro-Check Severity-Override

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

### Final Summary lesen

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

## Entwicklung an diesem Repository

### Regressionstests

```bash
bash tests/test_checks.sh
```

### Checks gegen dieses Repo (Dogfooding)

Einzelne Checks mit Ziel `.` (Repository-Root von Guardrails), aus dem Guardrails-Clone:

```bash
bash scripts/checks/domain/cicd_sec_04.sh .
bash scripts/checks/domain/cicd_sec_08.sh .
# … weitere Checks wie im Quick Start, Pfad . statt /pfad/zum/ziel-repo
```

In CI prüft [`.github/workflows/self-test.yml`](.github/workflows/self-test.yml) ausgewählte Checks auf diesem Repo.

### Modular package check architecture (`CICD-SEC-03`)

`CICD-SEC-03` behält seine öffentliche Designation und Workflow-Anbindung, nutzt intern aber ein Dispatcher-Muster. Das Top-Level-Skript orchestriert Sprachmodule mit stabiler Schnittstelle:

- input: repository root path
- output: findings via shared reporting library
- exit semantics: `0` (pass/warn), `1` (fail), `2` (missing runtime dependency)

Aktuelle Sprachmodule:

- `scripts/checks/domain/package/js_ts.sh`
- `scripts/checks/domain/package/python.sh`
- `scripts/checks/domain/package/go.sh`
- `scripts/checks/domain/package/rust.sh`
- `scripts/checks/domain/package/ruby.sh`
- `scripts/checks/domain/package/php.sh`

Das unterstützt Repositories mit einem Service im Root und Monorepos mit vielen verschachtelten Services.

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

**Version pinnen:** Siehe [Quick Start](#quick-start) — für CI, pre-commit und lokale Skripte aus einem Clone dieselbe Commit-SHA verwenden; nie ungepinnte Branch-Referenzen als einzige Quelle.

**gitleaks SHA:** Der `cicd-sec-06` Job lädt gitleaks herunter. Den Versions-Pin in `full-scan.yml` ggf. an die aktuelle Release ([gitleaks Releases](https://github.com/gitleaks/gitleaks/releases)) anpassen.

**GITHUB_WORKFLOW_REF:** Die Workflows parsen `GITHUB_WORKFLOW_REF` um den exakten Guardrails-SHA zu ermitteln – Skripte werden immer in der Version geladen die zum aufgerufenen Workflow passt.

**yq:** Auf GitHub-hosted Runnern vorinstalliert. Lokal: `brew install yq`. Wird sowohl von einzelnen Checks als auch vom `.guardrails.yml`-Reader genutzt; fehlt yq, fallen Werte auf konservative Defaults zurück (`mode=fail`).

**branch-basierte domain checks:** `cicd_sec_01_flow.sh` und `cicd_sec_05_branch.sh` benötigen für vollständige API-Auswertung ein Token mit Branch-Protection-Leserechten. Ohne geeigneten Token werden API-Pfade als Warnung/Skip behandelt.

**Rechte:** Alle anderen Checks brauchen nur `contents: read`. Keine Admin-Rechte erforderlich.
