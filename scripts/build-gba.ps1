$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dockerImage = 'devkitpro/devkitarm:latest'

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
docker info *> $null
$dockerStatus = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference

if ($dockerStatus -ne 0) {
    throw 'Docker Desktop is not running. Start it and run npm run build:gba again.'
}

docker run --rm `
    --volume "${projectRoot}:/workspace" `
    --workdir /workspace `
    $dockerImage `
    make -j2

if ($LASTEXITCODE -ne 0) {
    throw 'The GBA build failed.'
}

Write-Host "ROM generated at: $projectRoot\digimon_rpg.gba"

