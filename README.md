# cicd-guardrails

Wiederverwendbare GitHub Actions Workflows die automatisch gegen häufige CI/CD-Sicherheitsfehler prüfen.  
Grundlage: [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/).

---

## Was wird geprüft?

Skripte, Workflow-Job-IDs und Display-Namen folgen einheitlich der OWASP-Designation. Damit ist überall die gleiche Identität sichtbar (Skript ↔ Job ↔ Status-Check ↔ FB_CHECK_ID).

| Designation | Job-ID | Skript | Was wird erkannt |
|---|---|---|---|
| `CICD-SEC-01-FLOW` | `cicd-sec-01-flow` | `scripts/checks/domain/cicd_sec_01_flow.sh` | Branch-Flow-Kontrollen: PR-Pflicht, Approvals, force-push/delete Regeln |
| `CICD-SEC-03` | `cicd-sec-03` | `scripts/checks/domain/cicd_sec_03.sh` | Fehlende Lock-Files (npm, pip, Poetry, Go, Rust, Ruby, PHP) |
| `CICD-SEC-04` | `cicd-sec-04` | `scripts/checks/domain/cicd_sec_04.sh` | `pull_request_target` Verwendung (Poisoned Pipeline Execution) |
| `CICD-SEC-05-PERMISSIONS` | `cicd-sec-05-permissions` | `scripts/checks/domain/cicd_sec_05_permissions.sh` | Fehlende `permissions:` Blöcke auf Top-Level oder Job-Ebene |
| `CICD-SEC-05-BRANCH` | `cicd-sec-05-branch` | `scripts/checks/domain/cicd_sec_05_branch.sh` | Branch-Governance: Admin-Enforcement, stale reviews, code-owner policy |
| `CICD-SEC-05-RUNNER-ACCESS` | `cicd-sec-05-runner-access` | `scripts/checks/domain/cicd_sec_05_runner_access.sh` | Generische self-hosted Runner Labels ohne Segmentierung |
| `CICD-SEC-06` | `cicd-sec-06` | `scripts/checks/domain/cicd_sec_06.sh` | Hardcoded Secrets via gitleaks |
| `CICD-SEC-07-RUNNER-HARDENING` | `cicd-sec-07-runner-hardening` | `scripts/checks/domain/cicd_sec_07_runner_hardening.sh` | `--privileged` Container und `sudo` in Workflows |
| `CICD-SEC-08` | `cicd-sec-08` | `scripts/checks/domain/cicd_sec_08.sh` | Actions mit `@v1`, `@main`, `@latest` statt SHA-Pinning |

> **Migrationshinweis (Breaking Change):** Job-IDs und Display-Namen wurden auf das einheitliche `cicd-sec-*` Schema umgestellt. Konsumenten müssen ihre `skip-checks`-Eingaben und Branch-Protection-Required-Status-Checks anpassen. Mapping siehe Tabelle.

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
  - `🚨 CICD-SEC-04 (pull_request_target)`
  - `📌 CICD-SEC-08 (Action SHA-Pinning)`
  - `🔐 CICD-SEC-05-PERMISSIONS (Workflow permissions)`
  - `🔒 CICD-SEC-03 (Dependency Lock Files)`
  - `🕵️ CICD-SEC-06 (Secret Scanning)`
  - `🖥️ CICD-SEC-05-RUNNER-ACCESS (Runner access policy)`
  - `🧱 CICD-SEC-07-RUNNER-HARDENING (Runner hardening)`
  - `🧭 CICD-SEC-01-FLOW (Flow control)` ← nur mit Admin-Token sinnvoll
  - `🛂 CICD-SEC-05-BRANCH (Branch governance and PBAC)` ← nur mit Admin-Token sinnvoll
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
- `container_registry=public` erhöht Supply-Chain-Gewichtung (vor allem `CICD-SEC-08`, dann `CICD-SEC-06` und `CICD-SEC-04`); `private_network` reduziert sie geringfügig
- `data_sensitivity=high` und `deployment_criticality=prod|regulated` erhöhen Priorität für Secrets, Permissions und Runner-Kontrollen

Fehlt die Datei, nutzt Guardrails konservative Defaults und schreibt das transparent ins Summary.

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
- Gruppierung nach Severity
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
1. **CICD-SEC-04** — pull_request_target check
   - Status: `FAIL`
   - Problem: Privileged pull request execution can run untrusted contributor-controlled code.
   - Exploit path: A malicious fork PR can abuse privileged workflow context to execute trusted jobs with untrusted code.
   - Impact: Pipeline takeover with potential artifact tampering and secret exposure.
   - Fix first: Avoid pull_request_target for untrusted PRs. Separate privileged jobs and prevent checking out fork head refs.
   - Reference: [OWASP CICD-SEC-04](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-04-Poisoned-Pipeline-Execution/)
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
│   ├── checks/
│   │   ├── domain/                       # Fachliche Startpunkte (cicd_sec_*)
│   │   │   ├── cicd_sec_01_flow.sh
│   │   │   ├── cicd_sec_03.sh
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
│       └── feedback.sh                   # Reporting-Helper, Mode-Override
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
