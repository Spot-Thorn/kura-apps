# kura-apps

[![validate](https://github.com/Spot-Thorn/kura-apps/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/Spot-Thorn/kura-apps/actions/workflows/validate.yml)
[![feeds](https://github.com/Spot-Thorn/kura-apps/actions/workflows/feeds.yml/badge.svg?branch=main)](https://github.com/Spot-Thorn/kura-apps/actions/workflows/feeds.yml)

Installs the **latest** version of common Windows apps straight from each vendor. It's for machines that can't use the Microsoft Store or winget. There is one Kura action per app.

## Adding this source

In Kura, open **Sources** (top right), click **Add**, and paste:

https://raw.githubusercontent.com/Spot-Thorn/kura-apps/main/catalog.toml

The source is added **disabled**. Enable it, then click **Refresh**. To pin a fixed version, use a tag instead of `main`, e.g. `.../kura-apps/v1.0.0/catalog.toml`.

## Actions

| Action | Admin |
| --- | --- |
| Install Google Chrome · Mozilla Firefox · Microsoft Edge | yes |
| Install Zoom Workplace · Microsoft Teams (new) | yes |
| Install Discord · Slack | no (per-user) |
| Install 7-Zip · Notepad++ · VLC · Adobe Acrobat Reader · Everything · ShareX | yes |
| Install / Update Apps (pick from a list) | yes |

All actions use the `install` category, and none are destructive.

## What an action does

It shows the installed and latest version, then asks:

- **Already on the latest version:** reinstall silently, reinstall interactively, or cancel
- **Older or not installed:** silent install, interactive install, or cancel

The installer is downloaded to `%TEMP%`, verified, installed, and then deleted. Logs go to `C:\ProgramData\KuraApps\Logs\`.

**Outside Kura** (PDQ, RMM, a USB stick): every script in `scripts/` is self-contained. From an elevated PowerShell:

```powershell
.\install-chrome.ps1                  # same prompts as in Kura
.\install-chrome.ps1 -Unattended      # no prompts; skips if already current (add -Force to reinstall)
.\install-apps.ps1 -App updates       # update everything installed and outdated
.\install-apps.ps1 -List              # show installed vs latest for every app
```

Exit codes: `0` means success or already current, `1` means a failure, and `2` means the app list couldn't be loaded.

## Before you enable this

Adding a source means running whatever this repo publishes, on your machines, as administrator.

Every installer is checked before it runs:

- **Most apps** need a valid Authenticode signature.
- **Apps whose vendor doesn't sign** (7-Zip) must match the SHA-256 GitHub publishes for the release.
- **Any GitHub download** must match its published SHA-256, even if it's signed. A mismatch always blocks the install.

A few apps need extra care:

- **Discord and Slack** install per-user. Unattended runs as SYSTEM skip them unless you name them.
- **Teams** has no public "latest version" feed, so the script can't tell whether it's current.
- **Adobe Reader 64-bit** uses the same name as Acrobat Pro. Don't run it on machines that have Pro.

## Suggesting an app

Open an issue, or a pull request that changes only `apps.json`. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT; see [LICENSE](LICENSE).
