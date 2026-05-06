# cicd-guardrails

Wiederverwendbare GitHub Actions Workflows die automatisch gegen häufige CI/CD-Sicherheitsfehler prüfen.  
Grundlage: [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/).

---

## Was wird geprüft?

| Check | OWASP | Was wird erkannt |
|---|---|---|
| `check-prt` | CICD-SEC-04 | `pull_request_target` Verwendung (Poisoned Pipeline Execution) |
| `check-action-pinning` | CICD-SEC-08 | Actions mit `@v1`, `@main`, `@latest` statt SHA-Pinning |
| `check-permissions` | CICD-SEC-05 | Fehlende `permissions:` Blöcke auf Top-Level oder Job-Ebene |
| `check-dependency-pins` | CICD-SEC-03 | Fehlende Lock-Files (npm, pip, Poetry, Go, Rust, Ruby, PHP) |
| `check-secrets` | CICD-SEC-06 | Hardcoded Secrets via gitleaks |
| `check-flow-control` | CICD-SEC-01 | Branch-Flow-Kontrollen: PR-Pflicht, Approvals, force-push/delete Regeln |
| `check-pbac-branch-policy` | CICD-SEC-05 | Branch-Governance: Admin-Enforcement, stale reviews, code-owner policy |
| `check-runner-access` | CICD-SEC-05 | Generische self-hosted Runner Labels ohne Segmentierung |
| `check-runner-hardening` | CICD-SEC-07 | `--privileged` Container und `sudo` in Workflows |

---

## Einbindung in andere Repos

### 1. SHA des Guardrails-Repos ermitteln

```bash
git ls-remote https://github.com/YOUR_ORG/cicd-guardrails HEAD
# Ausgabe: abc123...def456  HEAD
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
  guardrails:
    uses: Christopher-Rust/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    #                                                                        ^^^^^
    #               Immer auf vollständigen SHA pinnen – nie @main oder @v1!
    with:
      strict: true
    secrets:
      app-id: ${{ secrets.APP_ID }}
      app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

> **Alternative ohne GitHub App:** `admin-token` als klassisches Secret übergeben.
>
> ```yaml
> jobs:
>   guardrails:
>     uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
>     with:
>       strict: true
>     secrets:
>       admin-token: ${{ secrets.GUARDRAILS_ADMIN_TOKEN }}
> ```
>
> Für JavaScript-basierte Actions nur Node24-kompatible Revisionen verwenden und weiterhin auf vollständige Commit-SHAs pinnen.
>
> Wird weder `admin-token` noch ein GitHub-App-Secret-Paar (`app-id` + `app-private-key`) übergeben,
> können branch-basierte Checks eingeschränkt sein oder Warnungen ausgeben.
> Alle file-basierten Checks laufen normal weiter.

### 3. Branch Protection konfigurieren (PRs blockieren)

GitHub → Repo Settings → Branches → Add rule → `main`:

- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- Required status checks (Namen exakt so eintragen):
  - `🚨 pull_request_target`
  - `📌 Action SHA-Pinning`
  - `🔐 Workflow-Permissions`
  - `🔒 Dependency Lock Files`
  - `🕵️ Secret Scanning (gitleaks)`
  - `🖥️ Runner-Konfiguration`
  - `🛡️ Branch Protection`  ← nur wenn GitHub App eingerichtet
- ✅ Do not allow bypassing the above settings

### 4. Migrationsmodus (für bestehende Repos)

Für Repos die noch nicht alle Regeln erfüllen – Findings anzeigen ohne den Build zu brechen:

```yaml
jobs:
  guardrails:
    uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    with:
      strict: false
      skip-checks: 'check-secrets,check-runner-hardening'
```

### 5. Risiko-Kontext über `.guardrails.yml` steuern

Der finale Job `📊 Risk summary` liest optional eine Datei `.guardrails.yml` im Ziel-Repo
und gewichtet Findings kontextabhängig (z. B. public vs private, self-hosted vs GitHub-hosted).

Referenzen im Root dieses Repos:

- `.guardrails.schema.json` (validation schema for tooling and IDEs)
- `.guardrails.example.yml` (copy-paste starter file)

Beispiel:

```yaml
# .guardrails.yml
context:
  visibility: public              # public | private | internal
  software_type: open_source      # open_source | private_software
  runner_type: self_hosted        # self_hosted | github_hosted
  data_sensitivity: high          # low | medium | high
  deployment_criticality: prod    # dev | prod | regulated
```

Wie die Werte einfließen:

- `visibility=public` erhöht Risiko-Gewichtung für `CICD-SEC-04`, `CICD-SEC-06`, `CICD-SEC-08`
- `software_type=open_source` gewichtet Supply-Chain/Exposure höher
- `runner_type=self_hosted` gewichtet Runner-Access- und Hardening-Themen höher
- `data_sensitivity=high` und `deployment_criticality=prod|regulated` erhöhen Priorität für Secrets, Permissions und Runner-Kontrollen

Fehlt die Datei, nutzt Guardrails konservative Defaults und schreibt das transparent ins Summary.

### 6. Final Summary lesen

Die finale Ausgabe im Job `📊 Risk summary` ist auf schnelle Priorisierung optimiert:

- Executive Snapshot mit Anzahl `Critical | High | Medium`
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

#### Critical
1. **CICD-SEC-04** — pull_request_target check
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
│   │   ├── domain/                       # Fachliche Startpunkte
│   │   │   ├── check_flow_control.sh
│   │   │   ├── check_pbac_branch_policy.sh
│   │   │   ├── check_runner_access.sh
│   │   │   └── check_runner_hardening.sh
│   │   └── tech/                         # Technische Adapter (API/Parsing/CLI)
│   │       ├── github_branch_protection_api.sh
│   │       └── workflow_runner_scan.sh
│   ├── check_prt.sh
│   ├── check_pinning.sh
│   ├── check_permissions.sh
│   ├── check_lockfiles.sh
│   ├── check_secrets.sh
│   ├── aggregate_risk_summary.sh
│   └── lib/feedback.sh
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
bash scripts/check_prt.sh          /pfad/zum/repo
bash scripts/check_pinning.sh      /pfad/zum/repo
bash scripts/check_permissions.sh  /pfad/zum/repo   # benötigt yq
bash scripts/check_lockfiles.sh    /pfad/zum/repo
bash scripts/checks/domain/check_runner_access.sh /pfad/zum/repo
bash scripts/checks/domain/check_runner_hardening.sh /pfad/zum/repo
GH_TOKEN=<dein-token> GITHUB_REPOSITORY=owner/repo bash scripts/checks/domain/check_flow_control.sh
GH_TOKEN=<dein-token> GITHUB_REPOSITORY=owner/repo bash scripts/checks/domain/check_pbac_branch_policy.sh

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

**gitleaks SHA:** Der `check-secrets` Job lädt gitleaks herunter. Den SHA-Platzhalter in `full-scan.yml` durch den echten SHA256 aus den [gitleaks Releases](https://github.com/gitleaks/gitleaks/releases) ersetzen (`sha256sums.txt`).

**GITHUB_WORKFLOW_REF:** Die Workflows parsen `GITHUB_WORKFLOW_REF` um den exakten Guardrails-SHA zu ermitteln – Skripte werden immer in der Version geladen die zum aufgerufenen Workflow passt.

**yq:** Auf GitHub-hosted Runnern vorinstalliert. Lokal: `brew install yq`.

**branch-basierte domain checks:** `check_flow_control.sh` und `check_pbac_branch_policy.sh` benötigen für vollständige API-Auswertung ein Token mit Branch-Protection-Leserechten. Ohne geeigneten Token werden API-Pfade als Warnung/Skip behandelt.

**Rechte:** Alle anderen Checks brauchen nur `contents: read`. Keine Admin-Rechte erforderlich.
