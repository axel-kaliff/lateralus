# finpilot Skills Router

## About

This directory contains task-oriented skill files for the finpilot bootc image template. Skills follow the Bluefin `docs/skills` pattern: each skill defines **when to use it**, **when not to**, the **core process**, **common rationalizations**, **red flags**, and a **verification checklist**.

## Skill Index

| Skill | What it covers |
|---|---|
| `finpilot-overview.md` | Repository architecture, file layout, and the task router table. **Start here.** |
| `finpilot-onboarding.md` | Bootstrap a new fork: rename, enable Actions, first green build, signing. |
| `finpilot-templates.md` | The 7 rename locations and template-repo maintenance rules. |
| `finpilot-packages.md` | Decision tree: where to add packages (dnf5, Brew, Flatpak). |
| `finpilot-custom.md` | Runtime layer: Brewfiles, Flatpaks, ujust, and validation. |
| `finpilot-build.md` | Containerfile, Justfile, build scripts, image pinning, advanced topics. |
| `finpilot-ci.md` | GitHub Actions, Renovate, composite actions, workflow pins. |
| `finpilot-maintain.md` | Ongoing work: Renovate PRs, README raptor updates, local test loops. |
| `finpilot-troubleshooting.md` | Symptom → cause → fix tables for build, CI, and runtime issues. |
| `finpilot-pr-checklist.md` | Pre-commit and per-change-type validation checklists. |
| `finpilot-examples.md` | Runnable example scripts and the `.example` → `.sh` activation pattern. |

## Quick Router

| I need to… | Read this skill |
|---|---|
| Bootstrap a new fork from this template | `finpilot-onboarding.md` |
| Add/remove a package or app | `finpilot-packages.md` |
| Change Brewfiles, Flatpaks, or ujust | `finpilot-custom.md` |
| Change Containerfile, Justfile, or build scripts | `finpilot-build.md` |
| Fix CI or Renovate | `finpilot-ci.md` / `finpilot-maintain.md` |
| Open a PR | `finpilot-pr-checklist.md` |
| Debug a build or deploy failure | `finpilot-troubleshooting.md` |
| Follow a worked example | `finpilot-examples.md` |

## How to Extend Skills

When adding a new skill:

1. **Copy an existing skill** as a template to maintain consistency
2. **Use frontmatter** with `name`, `description`, and `metadata` keys
3. **Include the standard sections**: When to Use, When NOT to Use, Core Process, Common Rationalizations, Red Flags, Verification
4. **Add to this README** in the index and quick router tables
5. **Link to the new skill** from `finpilot-overview.md` and wherever else relevant

## References

- [Bluefin skills](https://github.com/projectbluefin/bluefin/tree/main/docs/skills) — upstream pattern
- [AGENTS.md](../../AGENTS.md) — high-level copilot instructions and mandatory gates
