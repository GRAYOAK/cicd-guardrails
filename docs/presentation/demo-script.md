# Demo-Skript (5–10 Minuten)

Speaker-Notes für die interne Live-Demo. Outline der vier Blöcke: [README.md](README.md).

**Vorbereitung**

- Guardrails-Clone auf **derselben SHA wie der Demo-Pin** (well/errors `main`: `9802b5afffeb9e9097a2c73eae480ed62eab76be`). `origin/dev`-Spitze `dc65e0b` ist Harness/Docs — für den einen lokalen Check gegen well/errors den **Pin** nutzen.
- Geschwisterclones [`cicd-guardrails-demo-well`](https://github.com/GRAYOAK/cicd-guardrails-demo-well) und [`cicd-guardrails-demo-errors`](https://github.com/GRAYOAK/cicd-guardrails-demo-errors).
- `yq` installiert; `gitleaks` nur, wenn SEC-06 gezeigt wird.
- Optional: GitHub Actions der Demos im Tab offen halten.

---

## Ablauf

| Min | Was | Befehl / Ort |
|---|---|---|
| 0–1 | Ziel in einem Satz + Pin-Regel | `git ls-remote https://github.com/GRAYOAK/cicd-guardrails HEAD` |
| 1–3 | Ein lokaler Check | siehe unten |
| 3–5 | CI + pre-commit | well/errors `security.yml` und `.pre-commit-config.yaml` |
| 5–8 | well vs. errors | file-based grün vs. Findings; optional `task test:demos` |
| 8–10 | CTA | [issues/new](https://github.com/GRAYOAK/cicd-guardrails/issues/new) + Checkliste Block 4 |

### 0–1 — Ziel und Pin

Satz: Checks liegen nur in `cicd-guardrails`; geprüft wird das **Ziel-Repo**; immer **40-Zeichen-SHA**, nie `@main`.

```bash
git ls-remote https://github.com/GRAYOAK/cicd-guardrails HEAD
```

HEAD kann `dc65e0b…` (aktuelles `dev`) sein, während Demos auf `9802b5a…` pinnen — das ist Absicht (siehe Speaker Notes).

### 1–3 — Ein lokaler Check

Aus dem Guardrails-Clone (Pfad = Ziel-Root):

```bash
bash scripts/checks/domain/cicd_sec_04_poisoned_pipeline.sh ../cicd-guardrails-demo-well
bash scripts/checks/domain/cicd_sec_03_dependency_chain.sh ../cicd-guardrails-demo-errors
```

Ein Durchlauf reicht live. SEC-04 auf well soll durchlaufen; SEC-03 auf errors soll Findings liefern (reicht als „errors rot“).

### 3–5 — CI und pre-commit

Zeigen, nicht debuggen:

- [well `security.yml`](https://github.com/GRAYOAK/cicd-guardrails-demo-well/blob/main/.github/workflows/security.yml): kurzer Caller-Job-Name `scan`; `uses: GRAYOAK/cicd-guardrails/.github/workflows/full-scan.yml@9802b5afffeb9e9097a2c73eae480ed62eab76be` plus `guardrails-repository` / `guardrails-ref` (gleiche SHA).
- [errors `security.yml`](https://github.com/GRAYOAK/cicd-guardrails-demo-errors/blob/main/.github/workflows/security.yml): gleiches Pin-Muster; errors hat zusätzlich `generate-token` / `admin-token`.
- `.pre-commit-config.yaml`: `rev` **gleich** der `uses`-SHA.

README-Quick-Start zeigt noch `YOUR_ORG` + nur `strict: true`. Für den Workflow auf `dev` reichen diese zwei Inputs **nicht** — Demo-YAML ist die laufende Wahrheit.

### 5–8 — well vs. errors

- well: dateibasierte Checks grün.
- errors: Findings (SEC-03 reicht für den Harness).
- Optional:

```bash
task test:demos
```

(`bash tests/test_demo_repos.sh`; Geschwisterpfade oder `GUARDRAILS_DEMO_*_PATH`.) FLOW/BRANCH werden übersprungen. Exit 2 = Infra, nicht „errors rot“.

### 8–10 — Melden

[https://github.com/GRAYOAK/cicd-guardrails/issues/new](https://github.com/GRAYOAK/cicd-guardrails/issues/new): Ziel-Repo, 40-Zeichen-SHA, Weg, Check-ID, erwartet vs. tatsächlich, Logs ohne Secrets.

---

## Speaker Notes

Nicht als eigener Folienblock; nur sagen, wenn es hakt oder jemand nachfragt.

**SHA-Drift.** Clone ≠ CI `@SHA` ≠ pre-commit `rev` → anderes Verhalten. README: CI und pre-commit denselben Pin. Demo-Pin `9802b5a` ≠ `dev`-HEAD `dc65e0b`: Check-Verhalten = Demo-Pin; Produktstand = `origin/dev`.

**admin-token / FLOW / BRANCH.** Ohne Token skip/eingeschränkt. errors verdrahtet `generate-token` + `secrets.admin-token`; well `main` noch nicht. [well PR #2](https://github.com/GRAYOAK/cicd-guardrails-demo-well/pull/2) ist der Token-Job; Secrets und Branch Protection bleiben Org-Thema. Der lokale Harness skippt FLOW/BRANCH bewusst. well-CI-Rot bei Settings-Jobs ist **nicht** „Produkt kaputt“.

**yq.** Fehlt lokal → Defaults (`mode=fail`); Overlay/Policy-Merge schwächer. CI stellt yq über `.github/actions/setup-tools`. Lokal: `brew install yq`.

**gitleaks.** Nur SEC-06. Lokal oft Exit 2 ohne Binary im cwd. Nicht als erwartetes errors-Rot verkaufen.

**0.4.0 vs. `dev`.** Das Manifest auf dem Snapshot ist `0.4.0`; `main` kann ein anderes Release zeigen. Das gezeigte Produkt ist `origin/dev`, nicht die Release-Nummer.

**README vs. Caller.** Quick Start: `YOUR_ORG` + `with: strict` ohne `guardrails-repository` / `guardrails-ref`. Demo-`security.yml` und [migrations/v0.3.2.md](../../migrations/v0.3.2.md) sind die laufende Caller-Wahrheit. README in dieser Demo nicht umbauen.

**Hook-IDs.** Producer: slug-IDs (`cicd-sec-04-poisoned-pipeline`, …). Demo-`main` kann Legacy-IDs (`cicd-sec-04`, …) haben. Parität gilt für die SHA.

**#22.** Called-Jobs heißen kurz `setup`, `risk-summary`, `01-flow` … `08-action-pinning`; Consumer nutzen `jobs.guardrails.name: scan` oder lassen `name:` weg. Ampel bis Merge und Consumer-Migration gelb.
