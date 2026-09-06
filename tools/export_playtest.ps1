param(
    [string]$Commit = 'HEAD',
    [switch]$IncludeMac
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $revision = (git rev-parse --verify "$Commit^{commit}").Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source commit.' }
    $shortRevision = $revision.Substring(0, 7)
    $engine = Join-Path $projectRoot 'Godot_v4.6.2-stable_win64_console.exe'
    if (-not (Test-Path -LiteralPath $engine)) { throw "Missing engine: $engine" }
    $buildInfo = git show "${revision}:src/core/BuildInfo.gd"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read committed build identity.' }
    $identityMatch = [regex]::Match(($buildInfo -join "`n"), 'const PLAYTEST_BUILD := "(E-[0-9]+)"')
    if (-not $identityMatch.Success) { throw 'Missing playtest identity.' }
    $identity = $identityMatch.Groups[1].Value
    $outputDir = Join-Path $projectRoot "builds/playtest/${identity}_${shortRevision}"
    if (Test-Path -LiteralPath $outputDir) { throw "Refusing to overwrite existing build: $outputDir" }
    $scratchRoot = Join-Path $projectRoot ('builds/verification/export_' + [guid]::NewGuid().ToString('N'))
    $sourceDir = Join-Path $scratchRoot 'source'
    New-Item -ItemType Directory -Path $outputDir, $sourceDir | Out-Null
    $archive = Join-Path $scratchRoot 'source.zip'
    git archive --format=zip "--output=$archive" $revision
    if ($LASTEXITCODE -ne 0) { throw 'Source archive failed.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $sourceDir
    & $engine --headless --path $sourceDir --editor --import *> (Join-Path $scratchRoot 'import.log')
    if ($LASTEXITCODE -ne 0) { throw "Clean import failed; see $scratchRoot" }
    $baseName = 'BattleCapsule_' + $identity.Replace('-', '') + '_' + $shortRevision
    $exe = Join-Path $outputDir "$baseName.exe"
    & $engine --headless --path $sourceDir --export-release 'Windows Desktop' $exe *> (Join-Path $scratchRoot 'windows_export.log')
    if ($LASTEXITCODE -ne 0) { throw "Windows export failed; see $scratchRoot" }
    $artifacts = @($exe, (Join-Path $outputDir "$baseName.pck"))
    if ($IncludeMac) {
        $macZip = Join-Path $outputDir "${baseName}_macos_unsigned.zip"
        & $engine --headless --path $sourceDir --export-release 'macOS' $macZip *> (Join-Path $scratchRoot 'macos_export.log')
        if ($LASTEXITCODE -ne 0) { throw "macOS export failed; see $scratchRoot" }
        $artifacts += $macZip
    }
    $manifest = @(
        'Battle Capsule diagnostic playtest (not a public release)',
        "Build: $identity",
        "Source commit: $revision",
        "Built UTC: $([DateTime]::UtcNow.ToString('o'))",
        'Source: clean git archive; untracked working files excluded',
        "Windows launch: $exe",
        'Keep the EXE and PCK in the same directory.',
        'macOS, when included: unsigned cross-export; NOT tested on a Mac.',
        "Build logs/source: $scratchRoot",
        'SHA256:'
    )
    foreach ($artifact in $artifacts) {
        if (-not (Test-Path -LiteralPath $artifact)) { throw "Missing artifact: $artifact" }
        $checksum = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
        $manifest += "$($checksum.Hash)  $([IO.Path]::GetFileName($artifact))"
    }
    $manifest | Set-Content -LiteralPath (Join-Path $outputDir 'PLAYTEST_BUILD.txt') -Encoding UTF8
    Write-Output "PLAYTEST_EXE=$exe"
    Write-Output "PLAYTEST_SOURCE=$sourceDir"
    Write-Output "PLAYTEST_LOGS=$scratchRoot"
    Write-Output 'Export complete. Package integrity and runtime checks must pass before manual handoff.'
} finally {
    Pop-Location
}
