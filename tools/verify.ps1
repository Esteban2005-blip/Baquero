$ErrorActionPreference = 'Stop'

# El proyecto debe ejecutarse desde una ruta sin espacios en Windows para evitar
# que los hooks nativos de Dart / Flutter fallen al procesar rutas tipo
# "C:\Users\ESTEBAN PAREDES\...".
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace = $repoRoot
$shortRoot = 'C:\tmp\baquero'

if ($repoRoot.Contains(' ')) {
  if (-not (Test-Path $shortRoot)) {
    New-Item -ItemType Junction -Path $shortRoot -Target $repoRoot | Out-Null
  }
  $workspace = $shortRoot
}

$env:PUB_CACHE = 'C:\tmp\pub-cache'
$env:HOME = 'C:\tmp\home'
$env:USERPROFILE = 'C:\tmp\home'
New-Item -ItemType Directory -Path $env:PUB_CACHE, $env:HOME -Force | Out-Null

Set-Location $workspace

flutter pub get
if ($LASTEXITCODE) { exit $LASTEXITCODE }

dart run build_runner build
if ($LASTEXITCODE) { exit $LASTEXITCODE }

flutter analyze
if ($LASTEXITCODE) { exit $LASTEXITCODE }

flutter test
if ($LASTEXITCODE) { exit $LASTEXITCODE }

python -m pytest -q
exit $LASTEXITCODE
