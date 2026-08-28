---
target_version: NEXT
since_version: any
severity: additive
category: script
affected_consumers: [reusable-workflow, pre-commit, cli]
---

## What changed

`CICD-SEC-03-DEPENDENCY-CHAIN` now detects Dart projects by `pubspec.yaml` and requires a nonempty same-directory `pubspec.lock`.

## Why

Committed Dart lockfiles make resolved dependency versions reproducible for applications and Flutter projects.

## Required action for consumer repos

- Run `dart pub get` or `flutter pub get` in every detected Dart project.
- Commit the generated `pubspec.lock`.
- If local pre-commit configuration pins this repository, bump that pin after the producer change is merged.

## Detection

```bash
bash scripts/checks/domain/cicd_sec_03_dependency_chain.sh /path/to/consumer-repo
```

## Code examples

### Before

```text
services/dart-app/pubspec.yaml
```

### After

```text
services/dart-app/pubspec.yaml
services/dart-app/pubspec.lock
```
