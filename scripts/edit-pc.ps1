$ErrorActionPreference = 'Stop'

$projectPath = Join-Path $PSScriptRoot '..\pc'
$godot = Get-Command 'Godot_v4.7.2-stable_win64.exe' -ErrorAction SilentlyContinue

if (-not $godot) {
    $godot = Get-Command 'godot.exe' -ErrorAction SilentlyContinue
}

if (-not $godot) {
    throw 'Godot 4 não foi encontrado. Instale com: winget install GodotEngine.GodotEngine'
}

Start-Process -FilePath $godot.Source -ArgumentList @('--editor', '--path', ('"' + $projectPath + '"'))
