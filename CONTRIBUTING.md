# Contributing to kura-apps

## Suggesting an app

- **Easiest:** open an issue with the app's name and its official download page.
- **Pull request:** click the pencil icon on `apps.json`. GitHub forks the repo for you. Add the app using the [format below](#app-format), then click **Propose changes** and open the pull request.
  - Change **only `apps.json`**. The scripts and `catalog.toml` are generated automatically after the merge.
  - The validate check runs on your pull request, and the maintainer approves it before merging.
- **Download links must come from the vendor** (or the vendor's official GitHub releases). Mirrors and third-party download sites aren't accepted.

## Maintaining (repo owner or fork)

**Adding or changing an app on github.com:**

1. Edit `apps.json` (pencil icon) and commit to `main`, or merge a pull request.
2. The **validate** workflow regenerates `scripts/` and `catalog.toml`, checks everything, and commits them as **github-actions[bot]**. If the run goes red, nothing is committed.
3. Wait about 5 minutes, because raw.githubusercontent.com caches files, then click **Refresh** in Kura.

With a local clone instead, run `.\build.ps1` (Windows PowerShell 5.1 or 7) before pushing, or let the workflow do it.

**Rules:**

- Don't edit `scripts/` or `catalog.toml` by hand. The next build overwrites them.
- **Branch protection:** don't require pull requests on `main`. That would block your own web edits and the bot's auto-commit. If you ever turn that on, add GitHub Actions to the rule's bypass list.

**Settings at the top of `build.ps1`:**

- `$CatalogCategory` is `'install'` by default. Set it to `$null` to use each app's own category instead.
- `$IncludeMenuAction` turns the all-apps menu action on or off.
- `$ActionIdPrefix` sets the start of each action id (default `spot-install-`).

## App format

```jsonc
{
  "id": "putty",                          // lowercase; becomes install-putty.ps1 and spot-install-putty
  "name": "PuTTY",                        // action name: "Install PuTTY"
  "category": "Utilities",
  "perUser": false,                       // true = installs into the user profile; action doesn't need admin
  "signature": "required",                // or "unsigned" if the vendor doesn't sign (github type only; SHA-256 verified)
  "notes": "Optional text shown before the prompt and in the action description",
  "detect":   { ... },                    // how to find the installed version
  "latest":   { ... },                    // how to find the newest version
  "download": { "url": "...", "fileName": "..." },   // optional
  "installer": { "type": "msi", "silentArgs": "/qn /norestart", "interactiveArgs": "" }
}
```

### `detect`

Detection tries these in order and uses the first that finds something:

| Key | Example | Notes |
| --- | --- | --- |
| `files` | `["%ProgramFiles%\\PuTTY\\putty.exe"]` | Reads the exe's file version. Most reliable. |
| `appx` | `"MSTeams"` | Store/MSIX package name. |
| `displayName` | `"^PuTTY release"` | Regex on the Add/Remove Programs name. Checks HKLM 64-bit, HKLM 32-bit and HKCU. |

### `latest`

| `type` | Fields | What it does |
| --- | --- | --- |
| `json` | `url`, `path` | GETs JSON and reads a value, e.g. `versions[0].version`. |
| `redirect` | `url`, `regex` | Follows redirects without downloading. Takes the version from the final URL, which is also used as the download link. |
| `regex` | `url`, `regex` | Matches a regex on a web page. Needs a `(?<version>...)` group; an optional `(?<url>...)` group gives the download link. |
| `github` | `repo`, `assetRegex` | Latest GitHub release. The version comes from the tag, and the link from the first asset matching `assetRegex`. |
| `script` | `script` (a string or an array of lines) | PowerShell that returns `@{ Version = '...'; Url = '...' }`, for anything unusual (see Edge). |
| `none` | | No version feed. The app always shows as installable, and it needs `download.url`. |

### `download` (optional)

- `url` replaces the link found by `latest`. It can use `{version}` and `{versionNoDots}`.
- `fileName` is the local file name, and can use the same tokens. You need it when the URL doesn't end in `.msi` or `.exe`.

### `installer`

- `msi`: the script builds the command `msiexec /i <file> <args> /l*v <log>` itself. When you reinstall the same version, it adds `REINSTALL=ALL REINSTALLMODE=vomus` so the reinstall actually happens.
- `exe`: the downloaded file runs with the given args.

### `compare` (optional)

Use this when the installed and latest versions are written in different formats. Both keys are regex rewrites applied before comparing:

```json
"compare": {
  "latest":    { "pattern": "^(\\d+)\\.(\\d+)\\.\\d+\\.(\\d+)$", "replace": "$1.$2.$3" },
  "installed": { "pattern": "...", "replace": "..." }
}
```

Versions are compared number by number, and missing parts count as 0.

## Script options

- `-Unattended`, `-Force`
- `-App <ids|updates|all>`, `-Mode Silent|Interactive`
- `-List`, `-CheckFeeds`
- `-SkipSignatureCheck`, `-KeepDownloads`
- `-DownloadPath <dir>`, `-Manifest <path or URL>`

For details, run `Get-Help .\scripts\install-apps.ps1 -Full`.

## CI

- **validate** runs on every push and pull request. It:
  - regenerates the scripts
  - checks `catalog.toml` and `apps.json`
  - runs the unit tests
  - makes sure no script elevates itself
  - runs PSScriptAnalyzer

  On `main`, it then commits the regenerated files.
- **feeds** runs weekly, on changes, and on demand. It checks that every app's version lookup and download link still work.

## Layout

| Path | What it is |
| --- | --- |
| `apps.json` | The app list. **Edit this.** |
| `src/engine.ps1` | Shared installer logic, pasted into each generated script |
| `build.ps1` | Generates `scripts/` and `catalog.toml` |
| `scripts/`, `catalog.toml` | Generated; what Kura downloads |
| `tests/` | Unit tests |
