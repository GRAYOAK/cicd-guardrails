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
| `check-runner-config` | CICD-SEC-05/07 | `--privileged` Container, generische self-hosted Runner, sudo |

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
    uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    #                                                                ^^^^^
    #                  Immer auf vollständigen SHA pinnen – nie @main oder @v1!
    with:
      strict: true
```

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
- ✅ Do not allow bypassing the above settings

### 4. Migrationsmodus (für bestehende Repos)

Für Repos die noch nicht alle Regeln erfüllen – Findings anzeigen ohne den Build zu brechen:

```yaml
jobs:
  guardrails:
    uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
    with:
      strict: false
      skip-checks: 'check-secrets,check-runner-config'
```

---

## Repo-Struktur

```
cicd-guardrails/
├── .github/
│   └── workflows/
│       ├── full-scan.yml          # Reusable Orchestrator (von anderen Repos aufrufbar)
│       └── self-test.yml          # Dogfooding: dieses Repo prüft sich selbst
│
├── scripts/                       # Bash-Skripte – keine Dependencies nötig
│   ├── check_prt.sh               # pull_request_target Erkennung (awk)
│   ├── check_pinning.sh           # SHA-Pinning Enforcement (awk + grep)
│   ├── check_permissions.sh       # Permissions Blöcke (yq)
│   ├── check_lockfiles.sh         # Dependency Lock-Files (bash + find)
│   └── check_runner_config.sh     # Runner-Konfiguration (yq + grep)
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
bash scripts/check_runner_config.sh /pfad/zum/repo

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

**github.workflow_sha:** Die Workflows nutzen `github.workflow_sha` – Skripte werden immer exakt in der Version geladen die zum aufgerufenen Workflow passt. Kein separater Versions-Input nötig.

**yq:** Auf GitHub-hosted Runnern vorinstalliert. Lokal: `brew install yq`.

**Rechte:** Das Guardrails-Repo braucht nur `contents: read` auf die Ziel-Repos. Keine Admin-Rechte erforderlich.
