# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file is maintained automatically by [release-please](https://github.com/googleapis/release-please) from
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) on `main`. Do not edit manually.

For breaking-change migration steps targeted at automated consumers (including AI agents), see the
companion file `migrations/v<X.Y.Z>.md` released alongside each version.

## [0.2.1](https://github.com/Christopher-Rust/cicd-guardrails/compare/v0.2.0...v0.2.1) (2026-05-14)


### Features

* add scan coverage to checks and risk summary ([7d5a7a9](https://github.com/Christopher-Rust/cicd-guardrails/commit/7d5a7a9554764a3422aed9ae142d603aa9bee2a4))

## [0.2.0](https://github.com/Christopher-Rust/cicd-guardrails/compare/v0.1.0...v0.2.0) (2026-05-12)


### ⚠ BREAKING CHANGES

* Workflow pin findings move to the cicd-sec-03 job; cicd-sec-08 covers actions/** only. Update required checks and pre-commit file filters. See migrations/.unreleased/sec03-orchestrator-sec08-composite-only.md.
* Skill path moved from .cursor/skills/ to .agents/skills/. Update any local references or tooling that pointed at the old path.

### Features

* phase SEC-03 audits and scope SEC-08 to composite actions ([a76bbc2](https://github.com/Christopher-Rust/cicd-guardrails/commit/a76bbc2caf396341d2dd22907b61859d7a3b0523))
* relocate go-adjust-cicd-guardrails skill to .agents ([747860f](https://github.com/Christopher-Rust/cicd-guardrails/commit/747860f85908b91a53e3870bdba217cccdd785e4))


### Bug Fixes

* GITHUB_WORKFLOW_REF statt github.workflow_sha für guardrails-ref ([9553391](https://github.com/Christopher-Rust/cicd-guardrails/commit/9553391b98875d4e7b5ce91e0a5519a09fb8a83a))

## [Unreleased]

<!-- release-please will populate sections below this line -->
