$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$previewDirectory = Join-Path $projectRoot '.preview'

function Find-Mgba {
    $command = Get-Command 'mGBA.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'mGBA\mGBA.exe'),
        (Join-Path $env:ProgramFiles 'mGBA\mGBA.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'mGBA\mGBA.exe')
    )

    return $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

$mgbaPath = Find-Mgba
if (-not $mgbaPath) {
    throw 'mGBA was not found. Install it with: winget install --exact --id JeffreyPfau.mGBA'
}

$runJson = gh run list `
    --workflow build-gba.yml `
    --status success `
    --limit 1 `
    --json databaseId,headSha,createdAt

$runs = $runJson | ConvertFrom-Json
if (-not $runs -or $runs.Count -eq 0) {
    throw 'No successful GitHub build was found.'
}

$run = $runs[0]
$runDirectory = Join-Path $previewDirectory $run.databaseId
$romPath = Join-Path $runDirectory 'digimon_rpg.gba'
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null

if (-not (Test-Path -LiteralPath $romPath)) {
    Write-Host "Downloading build $($run.databaseId)..."
    gh run download $run.databaseId `
        --name digimon-rpg-gba `
        --dir $runDirectory
}

if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $romPath)) {
    throw 'The latest ROM artifact could not be downloaded.'
}

Write-Host "Opening $romPath"
$quotedRomPath = '"{0}"' -f $romPath
Start-Process -FilePath $mgbaPath -ArgumentList @($quotedRomPath)

