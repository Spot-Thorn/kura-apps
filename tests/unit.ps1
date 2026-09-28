# Unit tests for install-apps.ps1 helpers. Runs on any OS: pwsh ./tests/unit.ps1
$src = Join-Path $PSScriptRoot '../src/engine.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$null, [ref]$null)
$ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }
$fail = 0
function Check($name, $got, $want) { if ("$got" -ne "$want") { Write-Host "FAIL $name : got '$got' want '$want'"; $script:fail++ } else { Write-Host "ok   $name" } }
Check 'cmp equal pad'   (Compare-AppVersion '26.03' '26.03.00.0') 0
Check 'cmp older'       (Compare-AppVersion '24.09' '26.03') -1
Check 'cmp newer'       (Compare-AppVersion '155.0.1' '154.9.9') 1
Check 'cmp 10 vs 9'     (Compare-AppVersion '1.10' '1.9') 1
Check 'cmp prefix text' (Compare-AppVersion 'v8.9.8.1' '8.9.8.1') 0
Check 'cmp esr suffix'  (Compare-AppVersion '140.16.0esr' '140.16.0') 0
Check 'cmp unparsable'  ($null -eq (Compare-AppVersion 'abc' '1.0')) True
Check 'cmp huge part'   (Compare-AppVersion '1.99999999999999999999999' '1.2') 1
Check 'template'        (Expand-Template 'x/{version}/a{versionNoDots}.exe' '26.002.21931') 'x/26.002.21931/a2600221931.exe'
$chrome = '{"releases":[{"version":"154.0.8037.58","fraction":1}],"nextPageToken":""}' | ConvertFrom-Json
Check 'json chrome'     (Get-JsonPath $chrome 'releases[0].version') '154.0.8037.58'
$ff = '{"LATEST_FIREFOX_VERSION":"156.0.1"}' | ConvertFrom-Json
Check 'json firefox'    (Get-JsonPath $ff 'LATEST_FIREFOX_VERSION') '156.0.1'
$adobe = '{"products":{"reader":[{"displayName":"Reader 2026.002.21931","version":"26.002.21931"}],"dcPro":[]}}' | ConvertFrom-Json
Check 'json adobe'      (Get-JsonPath $adobe 'products.reader[0].version') '26.002.21931'
$def = [pscustomobject]@{ compare = [pscustomobject]@{ latest = [pscustomobject]@{ pattern='^(\d+)\.(\d+)\.\d+\.(\d+)$'; replace='$1.$2.$3' } } }
Check 'compare rewrite' (Get-CompareVersion $def '6.6.2.12345' 'latest') '6.6.12345'
Check 'compare no rule' (Get-CompareVersion $def '6.6.2' 'installed') '6.6.2'
$st = @(1..8 | ForEach-Object { [pscustomobject]@{ Def = [pscustomobject]@{ id = "a$_"; category = $(if ($_ -le 3) { 'Browsers' } else { 'Utilities' }) }; Status = $(if ($_ -eq 5) { 'Update available' } else { 'Up to date' }) } })
Check 'sel list/range'  ((Resolve-Selection '1,3 5-7' $st) -join ',') '0,2,4,5,6'
Check 'sel spaced range' ((Resolve-Selection '2 - 4' $st) -join ',') '1,2,3'
Check 'sel category'    ((Resolve-Selection 'browsers' $st) -join ',') '0,1,2'
Check 'sel updates'     ((Resolve-Selection 'updates' $st) -join ',') '4'
Check 'sel id+dupe'     ((Resolve-Selection 'a8 8 99' $st) -join ',') '7'
# checksums / unsigned apps
Check 'digest parse'    (Get-Sha256FromDigest ('sha256:' + ('ab' * 32))) (('AB' * 32))
Check 'digest bad'      ($null -eq (Get-Sha256FromDigest 'md5:abc')) True
Check 'digest empty'    ($null -eq (Get-Sha256FromDigest '')) True
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('kura-unit-' + [guid]::NewGuid() + '.bin')
[IO.File]::WriteAllText($tmp, 'hello kura')
$good = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
$unsignedApp = [pscustomobject]@{ id = 'x'; name = 'X'; signature = 'unsigned' }
$SkipSignatureCheck = $false
Check 'unsigned + hash ok'        (Test-Installer $unsignedApp ([pscustomobject]@{ Sha256 = $good }) $tmp $false) True
Check 'unsigned + hash mismatch'  (Test-Installer $unsignedApp ([pscustomobject]@{ Sha256 = ('0' * 64) }) $tmp $false) False
Check 'unsigned + no hash (unattended)' (Test-Installer $unsignedApp ([pscustomobject]@{ Sha256 = $null }) $tmp $false) False
$SkipSignatureCheck = $true
Check 'mismatch beats -SkipSignatureCheck' (Test-Installer $unsignedApp ([pscustomobject]@{ Sha256 = ('0' * 64) }) $tmp $false) False
Check 'no hash + -SkipSignatureCheck'      (Test-Installer $unsignedApp ([pscustomobject]@{ Sha256 = $null }) $tmp $false) True
$SkipSignatureCheck = $false
Remove-Item -LiteralPath $tmp -Force

# real apps.json regexes against realistic strings
$apps = (Get-Content (Join-Path $PSScriptRoot '../apps.json') -Raw | ConvertFrom-Json).apps
function App($id) { $apps | Where-Object id -eq $id }
Check 'discord re' ([regex]::Match('https://stable.dl2.discordapp.net/distro/app/stable/win/x64/1.0.9212/DiscordSetup.exe', (App discord).latest.regex).Groups['version'].Value) '1.0.9212'
Check 'zoom re'    ([regex]::Match('https://cdn.zoom.us/prod/6.6.2.12345/x64/ZoomInstallerFull.msi', (App zoom).latest.regex).Groups['version'].Value) '6.6.2.12345'
Check 'slack re'   ([regex]::Match('https://downloads.slack-edge.com/desktop-releases/windows/x64/4.46.101/SlackSetup.exe', (App slack).latest.regex).Groups['version'].Value) '4.46.101'
Check 'vlc re'     ([regex]::Match('<a href="//get.videolan.org/vlc/3.0.24/win64/vlc-3.0.24-win64.msi">', (App vlc).latest.regex).Groups['version'].Value) '3.0.24'
Check 'evt re'     ([regex]::Match('<a href="/Everything-1.5.0.1423b.x64-Setup.msi"><a href="/Everything-1.4.1.1032.x64.msi">', (App everything).latest.regex).Groups['version'].Value) '1.4.1.1032'
Check '7z asset'   ('7z2603-x64.msi' -match (App 7zip).latest.assetRegex) True
Check 'npp asset'  ('npp.8.9.8.1.Installer.x64.exe' -match (App notepadplusplus).latest.assetRegex) True
Check 'sharex asset' ('ShareX-21.0.0-setup-x64.exe' -match (App sharex).latest.assetRegex) True
Check 'reader detect' ('Adobe Acrobat (64-bit)' -match (App adobereader).detect.displayName) True
Check 'ff detect esr' ('Mozilla Firefox ESR (x64 en-US)' -match (App firefox).detect.displayName) False

# generated scripts: parse cleanly, embed a valid list, and point at the right app
$ids = @($apps.id)
foreach ($f in Get-ChildItem (Join-Path $PSScriptRoot '../scripts') -Filter '*.ps1') {
    $errs = $null
    $gast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
    $assign = @{}
    $gast.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] -and $args[0].Left.Extent.Text -in '$EmbeddedAppId', '$EmbeddedManifest' }, $true) |
        ForEach-Object { $assign[$_.Left.Extent.Text] = $_.Right.Extent.Text }
    $embeddedIds = @()
    try { $embeddedIds = @((([scriptblock]::Create($assign['$EmbeddedManifest'])).Invoke() | ConvertFrom-Json).apps.id) } catch { }
    $idText = $assign['$EmbeddedAppId']
    $expectId = if ($f.Name -eq 'install-apps.ps1') { '$null' } else { "'" + ($f.BaseName -replace '^install-', '') + "'" }
    Check "gen $($f.Name) parses"   (@($errs).Count) 0
    Check "gen $($f.Name) app id"   $idText $expectId
    Check "gen $($f.Name) list"     ($embeddedIds -join ',') ($ids -join ',')
}
Check 'gen one script per app + menu' (@(Get-ChildItem (Join-Path $PSScriptRoot '../scripts') -Filter '*.ps1').Count) ($ids.Count + 1)
Write-Host "$fail failure(s)"; exit $fail
