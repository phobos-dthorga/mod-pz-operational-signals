# Phobos PZ Mods — Release & Distribution Architecture

Canonical reference for versioning, tagging, packaging, and release practices
across all GekkoFyre / Phobos Project Zomboid (B42) mods.

## 1. Core Principles

- **Immutable Truth**: Every release is tied to a Git tag. Tags MUST NEVER be altered or deleted once published.
- **Separation of Stability**: Experimental and stable builds are clearly separated via pre-release flags.
- **Automation First**: CI/CD (GitHub Actions) is the authoritative release engine. Manual releases are discouraged.
- **Mod Ecosystem Awareness**: All mods declare dependencies with minimum version requirements.

## 2. Versioning Standard (SemVer)

All mods follow **Semantic Versioning**: `MAJOR.MINOR.PATCH`

| Component | Meaning |
|-----------|---------|
| MAJOR | Breaking API or save incompatibility |
| MINOR | New features, backwards-compatible |
| PATCH | Bug fixes, no feature changes |

### Pre-release Suffixes

Used for development builds:
- `vX.Y.Z-alpha.N` — Unstable, internal testing
- `vX.Y.Z-beta.N` — Feature-complete, testing
- `vX.Y.Z-rc.N` — Release candidate

### Bump Rules (from Conventional Commits)

| Commit Prefix | Bump Level |
|---------------|------------|
| `feat:` | Minor |
| `fix:`, `perf:` | Patch |
| `BREAKING CHANGE:` or `feat!:` | Major |
| `docs:`, `chore:`, `refactor:`, `test:`, `ci:` | Patch (if only these) |

## 3. Release Channels

### Stable Channel
- Tags: `v1.2.0` (bare SemVer)
- GitHub: normal release, marked as "Latest"
- Audience: all users
- Source: `main` branch only

### Pre-release Channel
- Tags: `v1.3.0-beta.1` (SemVer with suffix)
- GitHub: pre-release flag enabled
- Audience: testers, early adopters
- Source: dev branches

## 4. Branch Strategy

| Branch | Purpose | Release Type |
|--------|---------|-------------|
| `main` | Stable production code | Stable releases |
| `dev/*` | Active development | Pre-releases |

Flow: `dev → testing → tag pre-release → dev → merge → main → tag stable`

## 5. Tagging Rules (STRICT)

### Format
- Always prefixed with `v`: `v1.0.0`, `v0.10.0-beta.1`
- Always **annotated** tags: `git tag -a v1.0.0 -m "Release v1.0.0"`
- Never lightweight tags for releases

### Anti-Patterns (FORBIDDEN)
- Re-tagging releases (deleting and recreating a tag)
- Editing version numbers post-release
- Mixing stable and experimental in the same tag
- Uploading assets without version alignment
- Pushing tags without annotation

## 6. ZIP Packaging

Each release includes a clean mod ZIP containing ONLY game-relevant files.

### Included
- `mod.info` (root and version-specific)
- `common/` (all Lua code, scripts, textures, sandbox-options)
- `42/` or `42.14/` + `42.15/` (version-specific translations)
- `poster.png`, `icon.png`
- `CHANGELOG.md`, `LICENSE`

### Excluded
- `.git/`, `.github/`, `.gitignore`, `.gitattributes`, `.githooks/`
- `.luacheckrc`
- `build/`, `dist/`
- `docs/` (design documents, not shipped)
- `scripts/` (build tools, not shipped)
- `*.psd`, `*.kra`, `*.blend` (source art)
- `node_modules/`, `.idea/`, `.vscode/`
- `CONTRIBUTING.md`, `SECURITY.md`, `VERSIONING.md`

## 7. Manifest Format

Each release attaches a machine-readable `manifest.json`:

```json
{
  "name": "POSnet",
  "tag": "v0.10.0",
  "version": "0.10.0",
  "channel": "stable",
  "gameVersion": "B42",
  "repository": "phobos-dthorga/mod-pz-operational-signals",
  "commit": "abc123def456...",
  "releasedAt": "2026-03-19T00:00:00Z",
  "dependencies": {
    "PhobosLib": ">=1.40.0",
    "AZASFrequencyIndex": ">=0.1.0"
  }
}
```

### Dependency Declarations

Each repo declares hard dependencies in `dependencies.json` at the repo root:

| Mod | Dependencies |
|-----|-------------|
| POSnet | PhobosLib >=1.40.0, AZASFrequencyIndex >=0.1.0 |
| PhobosLib | (none) |
| PCP | PhobosLib >=1.30.0, ZVirusVaccine42BETA >=0.1.0 |
| PIP | PhobosLib >=1.30.0 |
| EPRCleanup | PhobosLib >=1.3.0 |

## 8. CI Pipeline (release.yml)

Triggered on tag push (`v*`). Steps:

1. **Validate** — Check tag matches SemVer format
2. **Detect channel** — Parse pre-release suffix (alpha/beta/rc → pre-release)
3. **Build package** — rsync with exclusions → ZIP
4. **Generate manifest** — `scripts/generate_manifest.py` with dependency declarations
5. **Upload artifacts** — ZIP + manifest as workflow artifacts
6. **Create release** — `gh release create` with auto-generated notes + assets

Pre-releases are flagged automatically. Stable releases are marked as "Latest".

## 9. Release Note Categories

GitHub auto-generated notes are sorted by `.github/release.yml`:

| Category | Commit Prefixes |
|----------|----------------|
| Features | `feat`, `feature`, `enhancement` |
| Fixes | `fix`, `bug`, `bugfix`, `regression` |
| Documentation | `docs`, `documentation` |
| Maintenance | `chore`, `refactor`, `test`, `ci`, `build` |

## 10. Claude Execution Directives

### When Releasing
1. Determine version bump level (SemVer rules from commit prefixes)
2. Create annotated tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
3. Push tag: `git push origin vX.Y.Z`
4. CI handles the rest (ZIP, manifest, release creation)
5. Verify release on GitHub (assets attached, correct channel flag)

### When Developing
- Use dev branches
- Use pre-release tags for testing (`v0.10.0-beta.1`)
- Never push stable tags from dev branches

### When Unsure
- Default to **pre-release** (beta)
- Default to **patch** bump
- Never publish stable unless API and save expectations are verified
