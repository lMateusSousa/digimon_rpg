$ErrorActionPreference = 'Stop'

$projectPath = Join-Path $PSScriptRoot '..\pc'
$godot = Get-Command 'Godot_v4.7.2-stable_win64_console.exe' -ErrorAction SilentlyContinue

if (-not $godot) {
    $godot = Get-Command 'godot_console.exe' -ErrorAction SilentlyContinue
}

if (-not $godot) {
    throw 'Godot 4 não foi encontrado.'
}

& $godot.Source --headless --path $projectPath --script 'res://tests/test_fighters.gd'
$testExitCode = $LASTEXITCODE
if ($null -ne $testExitCode -and $testExitCode -ne 0) {
    throw "Os testes do jogo falharam com código $testExitCode."
}
