# Lance les tests unitaires sous Windows, sans affichage. Equivalent de test.sh.
# Usage : .\test.ps1   (Godot 4.7+ dans le PATH ou dans $env:GODOT_PATH, Git for Windows installe)
# Les reglages, le lancement au demarrage et le dossier d'execution sont
# rediriges vers un dossier temporaire : rien de l'utilisateur n'est touche.
Set-Location $PSScriptRoot
$godot = if ($env:GODOT_PATH) { $env:GODOT_PATH } else { 'godot' }
if (-not (Get-Command $godot -ErrorAction SilentlyContinue)) {
	Write-Host "Godot introuvable. Indiquer Godot : `$env:GODOT_PATH = 'C:\chemin\godot_console.exe'"
	exit 1
}
# Les tests appellent sh et rm : ceux de Git for Windows.
$git = Split-Path (Split-Path (Get-Command git).Source) -Parent
$env:PATH = "$git\usr\bin;$git\bin;$env:PATH"
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("paros-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force "$sandbox\appdata", "$sandbox\data", "$sandbox\run" | Out-Null
$env:APPDATA = "$sandbox\appdata"
$env:XDG_DATA_HOME = "$sandbox\data"
$env:XDG_RUNTIME_DIR = "$sandbox\run"
try {
	if (-not (Test-Path .godot)) { & $godot --headless --path . --import *> $null }
	$output = & $godot --headless --path . res://tests/run.tscn -- @args 2>&1
	$status = $LASTEXITCODE
	$output | Where-Object { $_ -notmatch '^Godot Engine' -and $_ -ne '' }
} finally {
	Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
}
exit $status
