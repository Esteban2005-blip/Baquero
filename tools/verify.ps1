$ErrorActionPreference = 'Stop'
# Run from the repository root, with Flutter and Python on PATH.
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
