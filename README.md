# kura-apps

[![validate](https://github.com/Spot-Thorn/kura-apps/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/Spot-Thorn/kura-apps/actions/workflows/validate.yml)
[![feeds](https://github.com/Spot-Thorn/kura-apps/actions/workflows/feeds.yml/badge.svg?branch=main)](https://github.com/Spot-Thorn/kura-apps/actions/workflows/feeds.yml)

Installs the **latest** version of common Windows apps straight from each vendor. It's for machines that can't use the Microsoft Store or winget. There is one Kura action per app.

## Adding this source

In Kura, open **Sources** (top right), click **Add**, and paste:

https://raw.githubusercontent.com/Spot-Thorn/kura-apps/main/catalog.toml

The source is added **disabled**. Enable it, then click **Refresh**. Kura downloads the catalog and every script it names, and caches them.

To pin to a fixed version, use a tag instead of `main`: `.../kura-apps/v1.0.0/catalog.toml`.

## Actions

| Action | Category | Admin | Destructive |
| --- | --- | --- | --- |
| Install Google Chrome | install | yes | no |
| Install Mozilla Firefox | install | yes | no |
| Install Microsoft Edge | install | yes | no |
| Install Discord | install | no (per-user) | no |
| Install Zoom Workplace | install | yes | no |
| Install Microsoft Teams (new) | install | yes | no |
| Install Slack | install | no (per-user) | no |
| Install 7-Zip | install | yes | no |
| Install Notepad++ | install | yes | no |
| Install VLC media player | install | yes | no |
| Install Adobe Acrobat Reader | install | yes | no |
| Install Everything (voidtools) | install | yes | no |
| Install ShareX | install | yes | no |
| Install / Update Apps (pick from a list) | install | yes | no |

## What an action does

```
Checking Google Chrome...

   #  Category       App                      Installed         Latest            Status
 -----------------------------------------------------------------------------------------------
   1  Browsers       Google Chrome            152.0.7990.12     154.0.8037.58     Update available

== Google Chrome ==
   Installed: 152.0.7990.12   Latest: 154.0.8037.58
Install?
[S] Silent install  [I] Interactive install  [C] Cancel
```

- **Already on the latest version:** Reinstall silently, Reinstall interactively, or Cancel
- **Older or not installed:** Silent install, Interactive install, or Cancel

The installer is downloaded to `%TEMP%`, its digital signature is checked, it's installed, and then it's deleted. At the end the window waits for Enter so you can read the result.

Logs go to `C:\ProgramData\KuraApps\Logs\`: one log per day, plus a detailed `msiexec` log for each MSI.

**Install / Update Apps** is the same flow for every app at once. To pick apps, type numbers (`1,3,5-7`), a category (`Browsers`), an app id (`vlc`), `all`, or `updates`.

### Outside Kura (PDQ, RMM, a USB stick)

Every script in `scripts/` is self-contained, so you can copy just the one you need. From an elevated PowerShell:

```powershell
.\install-chrome.ps1                          # same prompts as in Kura
.\install-chrome.ps1 -Unattended              # no prompts; skips if already current
.\install-chrome.ps1 -Unattended -Force       # no prompts; reinstall even if current
.\install-apps.ps1 -App updates               # update everything installed and outdated
.\install-apps.ps1 -App chrome,7zip -Mode Interactive
.\install-apps.ps1 -List                      # table of every app, then exit
```

For PDQ, deploy `install-<app>.ps1 -Unattended`. Exit codes are `0` for success or already current, `1` for a failure, and `2` if the app list couldn't be loaded.

Other options:

- `-SkipSignatureCheck`
- `-KeepDownloads`
- `-DownloadPath <dir>`
- `-Manifest <path or URL to an apps.json>`

## Before you enable this

Adding a source means running whatever this repo publishes, on your machines, as administrator. That includes the download URLs and any `script`-type lookups in `apps.json`, since they're pasted into every script. Turn on branch protection for `main`, and read diffs to `apps.json` like code.

Every downloaded installer is checked before it runs:

- **Most apps** need a valid Authenticode signature.
- **Apps whose vendor doesn't sign installers** (7-Zip) are marked `"signature": "unsigned"`. Their download has to match the SHA-256 that GitHub publishes with the release instead.
- **Any GitHub download**, signed or not, has to match its published SHA-256. A mismatch always blocks the install, even with `-SkipSignatureCheck`.

If a check can't be passed, you're asked before the installer runs interactively, and `-Unattended` refuses it.

Some apps need extra care:

- **Discord and Slack** install into the current user's profile. Their actions don't ask Kura for admin, and unattended runs as SYSTEM skip them unless they're named explicitly.
- **Teams** has no public "latest version" feed. The script shows whether it's installed, but can't tell whether it's current.
- **Adobe Reader 64-bit** registers under the same name as Acrobat Pro. Don't run it on machines that have Pro.

## Adding or changing an app

Everything can be done on github.com:

1. Open `apps.json` and click the pencil icon. Add or change an app (the format is described below), then click **Commit changes** to `main`.
2. Wait about a minute. The **validate** workflow regenerates `scripts/` and `catalog.toml` from your edit, checks everything, and commits them as **github-actions[bot]**.
   - If the run goes red, nothing is committed. Open the run to see which check failed.
3. In Kura, click **Refresh**.

With a local clone instead, run `.\build.ps1` (Windows PowerShell 5.1 or PowerShell 7) before pushing, or let the workflow do it.

Don't edit `scripts/` or `catalog.toml` by hand. Both are generated from `apps.json` plus `src/engine.ps1`, and the next build overwrites them.

Settings at the top of `build.ps1`:

- **`$CatalogCategory`** is `'install'` for everything by default. Set it to `$null` to use each app's own category (browsers, communication, utilities).
- **`$IncludeMenuAction`** turns the all-apps menu action on or off.
- **`$ActionIdPrefix`** sets the start of each action id (default `spot-install-`).

### App format

```jsonc
{
  "id": "putty",                          // lowercase; becomes install-putty.ps1 and spot-install-putty
  "name": "PuTTY",                        // action name: "Install PuTTY"
  "category": "Admin",
  "perUser": false,                       // true = installs into the user profile; action doesn't need admin
  "signature": "required",                // or "unsigned" if the vendor doesn't sign (github type only; verified by SHA-256)
  "notes": "Optional text shown before the prompt and added to the action description",
  "detect":   { ... },                    // how to find the installed version
  "latest":   { ... },                    // how to find the newest version
  "download": { "url": "...", "fileName": "..." },   // optional, see below
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
| `redirect` | `url`, `regex` | Follows redirects without downloading and pulls the version from the final URL, which is also used as the download URL. This is the trick PDQ uses for Discord. |
| `regex` | `url`, `regex` | GETs a web page and matches a regex. It needs a `(?<version>...)` group; an optional `(?<url>...)` group gives the download link. |
| `github` | `repo`, `assetRegex` | Latest GitHub release. The version comes from the tag, and the link from the first asset matching `assetRegex`. Set the `GITHUB_TOKEN` environment variable to avoid GitHub's limit of 60 requests per hour. |
| `script` | `script` (a string or an array of lines) | PowerShell that returns `@{ Version = '...'; Url = '...' }`, for anything unusual (see Edge). |
| `none` | | No version feed. The app always shows as installable, and it needs `download.url`. |

### `download` (optional)

- **`url`** replaces the link found by `latest`. It can use `{version}` and `{versionNoDots}`.
- **`fileName`** is the local file name, and can use the same tokens. You need it when the URL doesn't end in `.msi` or `.exe`.

### `installer`

- **`msi`:** the script builds the command `msiexec /i <file> <args> /l*v <log>` itself. When you reinstall the exact same version, it adds `REINSTALL=ALL REINSTALLMODE=vomus` so the reinstall actually happens.
- **`exe`:** the downloaded file runs with the given args.

### `compare` (optional)

Use this when the installed version and the latest version are written in different formats. Both keys are regex rewrites applied before the versions are compared:

```json
"compare": {
  "latest":    { "pattern": "^(\\d+)\\.(\\d+)\\.\\d+\\.(\\d+)$", "replace": "$1.$2.$3" },
  "installed": { "pattern": "...", "replace": "..." }
}
```

Versions are compared number by number. Missing parts count as 0, so `26.03` equals `26.03.00.0`.

## CI

- **validate:** runs on every push.
  - `catalog.toml` parses, and every script it names exists.
  - `apps.json` is checked for:
    - unique, valid ids
    - required fields
    - known `latest` and `installer` types
    - regexes that compile
    - only known `{tokens}` in URLs and file names
  - `scripts/` and `catalog.toml` are regenerated with `build.ps1` first, so every check runs on what will be published. On `main`, the regenerated files are committed back automatically once all checks pass.
  - Unit tests pass. They cover version comparison, menu selection, the vendor version patterns, and that every generated script parses and embeds the right app.
  - No script elevates itself.
  - PSScriptAnalyzer reports no errors.
- **feeds:** runs weekly, when `apps.json` or the engine changes, and on demand. For every app it looks up the latest version and checks that the download link answers, so a vendor changing their URLs turns this badge red.

## Layout

- `catalog.toml`: Kura action definitions, at the repo root (generated)
- `scripts/`: a flat folder of `.ps1` files, one per app plus `install-apps.ps1` (generated)
- `apps.json`: the app list. **Edit this.**
- `src/engine.ps1`: the shared installer logic. Kura doesn't download it; it's pasted into each script.
- `build.ps1`: the generator
- `tests/`: unit tests

## License

MIT; see [LICENSE](LICENSE).
