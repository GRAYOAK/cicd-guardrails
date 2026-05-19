# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file is maintained automatically by [release-please](https://github.com/googleapis/release-please) from
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) on `main`. Do not edit manually.

For breaking-change migration steps targeted at automated consumers (including AI agents), see the
companion file `migrations/v<X.Y.Z>.md` released alongside each version.

## [0.4.0](https://github.com/GRAYOAK/cicd-guardrails/compare/v0.3.2...v0.4.0) (2026-05-19)


### ⚠ BREAKING CHANGES

* resolve migration conflict; move scan_repo notes to v0.3.3
* full-scan.yml uses path scan_repo; consumers must pin a new SHA or update forked workflows. See migrations/v0.3.2.md.

### Bug Fixes

* gitleaks version bug ([aaf3fef](https://github.com/GRAYOAK/cicd-guardrails/commit/aaf3fef8d6a2aaaf6953067450b371b1ac5b0bdb))
* rename caller checkout path from target to scan_repo ([1d30dc9](https://github.com/GRAYOAK/cicd-guardrails/commit/1d30dc9ba0aae390a1fbc44b1c559c4cf300b074))
* resolve migration conflict; move scan_repo notes to v0.3.3 ([9e402dc](https://github.com/GRAYOAK/cicd-guardrails/commit/9e402dc089b0a67c3691aba7f201e71bbec34b58))

## [0.3.2](https://github.com/GRAYOAK/cicd-guardrails/compare/v0.3.1...v0.3.2) (2026-05-16)


### Bug Fixes

* only flag YAML uses keys in workflow action pin audit ([04234e8](https://github.com/GRAYOAK/cicd-guardrails/commit/04234e8e7f70ae492d68e227e8cf4eee0ea35bea))
* require explicit guardrails pin inputs for cross-repo callers ([337553d](https://github.com/GRAYOAK/cicd-guardrails/commit/337553d5212bf391d96274871323a9f9951a1855))

## [0.3.1](https://github.com/GRAYOAK/cicd-guardrails/compare/v0.3.0...v0.3.1) (2026-05-16)


### Bug Fixes

* checkout guardrails scripts from caller-pinned repository ([7fccc09](https://github.com/GRAYOAK/cicd-guardrails/commit/7fccc09fc04a87149547e7e43edf6f719e106d4d))

## [0.3.0](https://github.com/GRAYOAK/cicd-guardrails/compare/v0.2.5...v0.3.0) (2026-05-16)


### ⚠ BREAKING CHANGES

* Workflow pin findings move to the cicd-sec-03 job; cicd-sec-08 covers actions/** only. Update required checks and pre-commit file filters. See migrations/.unreleased/sec03-orchestrator-sec08-composite-only.md.
* Skill path moved from .cursor/skills/ to .agents/skills/. Update any local references or tooling that pointed at the old path.

### Features

* add scan coverage to checks and risk summary ([7d5a7a9](https://github.com/GRAYOAK/cicd-guardrails/commit/7d5a7a9554764a3422aed9ae142d603aa9bee2a4))
* phase SEC-03 audits and scope SEC-08 to composite actions ([a76bbc2](https://github.com/GRAYOAK/cicd-guardrails/commit/a76bbc2caf396341d2dd22907b61859d7a3b0523))
* refactor readme ([#12](https://github.com/GRAYOAK/cicd-guardrails/issues/12)) ([76bca46](https://github.com/GRAYOAK/cicd-guardrails/commit/76bca46eeef3561cf1b516ac0b4e47584e3562ed))
* relocate go-adjust-cicd-guardrails skill to .agents ([747860f](https://github.com/GRAYOAK/cicd-guardrails/commit/747860f85908b91a53e3870bdba217cccdd785e4))
* update auto update ([1bc3929](https://github.com/GRAYOAK/cicd-guardrails/commit/1bc3929f2a30d03417a66c37b2917a7b9edd06e0))
* update auto update ([#8](https://github.com/GRAYOAK/cicd-guardrails/issues/8)) ([0277471](https://github.com/GRAYOAK/cicd-guardrails/commit/02774715f33a4dabd4bd01fb8d77a2c0b3eeef27))
* update default config ([4d3080d](https://github.com/GRAYOAK/cicd-guardrails/commit/4d3080da11bab41f315a3f8488007db0e6d65c7e))
* update default config ([#6](https://github.com/GRAYOAK/cicd-guardrails/issues/6)) ([0709d6e](https://github.com/GRAYOAK/cicd-guardrails/commit/0709d6efc74de2ba863c75726de38faf25e44e3b))
* update python output ([e88897a](https://github.com/GRAYOAK/cicd-guardrails/commit/e88897ad7c0b936d0483bd21ac2ad1a8fadabbdb))
* update python output ([#10](https://github.com/GRAYOAK/cicd-guardrails/issues/10)) ([76ae2b7](https://github.com/GRAYOAK/cicd-guardrails/commit/76ae2b7781ecf6e87fa6435cbaab350e6786be09))


### Bug Fixes

* GITHUB_WORKFLOW_REF statt github.workflow_sha für guardrails-ref ([9553391](https://github.com/GRAYOAK/cicd-guardrails/commit/9553391b98875d4e7b5ce91e0a5519a09fb8a83a))
* permissions error ([abf5e94](https://github.com/GRAYOAK/cicd-guardrails/commit/abf5e94a67951da89bbf21ab6c42a6816d70f06e))
* pipeline errors ([c810a3a](https://github.com/GRAYOAK/cicd-guardrails/commit/c810a3a1fd48e9c876b92f29041af3e0d7192478))

## [0.2.5](https://github.com/Christopher-Rust/cicd-guardrails/compare/v0.2.4...v0.2.5) (2026-05-16)


### Features

* refactor readme ([#12](https://github.com/Christopher-Rust/cicd-guardrails/issues/12)) ([76bca46](https://github.com/Christopher-Rust/cicd-guardrails/commit/76bca46eeef3561cf1b516ac0b4e47584e3562ed))

## [0.2.4](https://github.com/Christopher-Rust/cicd-guardrails/compare/v0.2.3...v0.2.4) (2026-05-15)


### Features

* update python output ([e88897a](https://github.com/Christopher-Rust/cicd-guardrails/commit/e88897ad7c0b936d0483bd21ac2ad1a8fadabbdb))
* update python output ([#10](https://github.com/Christopher-Rust/cicd-guardrails/issues/10)) ([76ae2b7](https://github.com/Christopher-Rust/cicd-guardrails/commit/76ae2b7781ecf6e87fa6435cbaab350e6786be09))

## [0.2.3](https://github.com/Christopher-Rust/cicd-guardrails/compare/v0.2.2...v0.2.3) (2026-05-14)


### Features

* update auto update ([1bc3929](https://github.com/Christopher-Rust/cicd-guardrails/commit/1bc3929f2a30d03417a66c37b2917a7b9edd06e0))
* update auto update ([#8](https://github.com/Christopher-Rust/cicd-guardrails/issues/8)) ([0277471](https://github.com/Christopher-Rust/cicd-guardrails/commit/02774715f33a4dabd4bd01fb8d77a2c0b3eeef27))

## [0.2.2](https://github.com/Christopher-Rust/cicd-guardrails/compare/v0.2.1...v0.2.2) (2026-05-14)


### Features

* update default config ([4d3080d](https://github.com/Christopher-Rust/cicd-guardrails/commit/4d3080da11bab41f315a3f8488007db0e6d65c7e))
* update default config ([#6](https://github.com/Christopher-Rust/cicd-guardrails/issues/6)) ([0709d6e](https://github.com/Christopher-Rust/cicd-guardrails/commit/0709d6efc74de2ba863c75726de38faf25e44e3b))

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
