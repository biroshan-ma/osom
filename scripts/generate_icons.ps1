# Script: scripts/generate_icons.ps1
# Purpose: Export a 2048x2048 PNG from assets/images/logo.svg and run flutter_launcher_icons.
# Usage (PowerShell):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   cd <project-root>
#   .\scripts\generate_icons.ps1

param(
    [string]$SvgPath = "assets/images/logo.svg",
    [string]$OutPngPath = "assets/images/logo_2048.png",
    [string]$ForegroundOut = "assets/images/icon_foreground.png",
    [int]$Size = 2048
)

function Write-Notice($s){ Write-Host "[generate-icons] $s" -ForegroundColor Cyan }

Write-Notice "Starting icon generation script"

if (-not (Test-Path $SvgPath)) {
    Write-Host "ERROR: SVG not found at $SvgPath" -ForegroundColor Red
    exit 1
}

# Locate Inkscape
$inkscapeCmd = $null
# Try common installation paths on Windows
$possiblePaths = @(
    "C:\\Program Files\\Inkscape\\bin\\inkscape.exe",
    "C:\\Program Files (x86)\\Inkscape\\bin\\inkscape.exe"
)
foreach ($p in $possiblePaths) {
    if (Test-Path $p) { $inkscapeCmd = $p; break }
}
# Also allow inkscape on PATH
if (-not $inkscapeCmd) {
    try {
        $which = (Get-Command inkscape -ErrorAction Stop).Source
        if ($which) { $inkscapeCmd = $which }
    } catch { }
}

if (-not $inkscapeCmd) {
    Write-Host "Inkscape not found on the system.\nPlease install Inkscape (https://inkscape.org) or export a PNG manually at ${Size}x${Size} and save it to $OutPngPath." -ForegroundColor Yellow
    Write-Notice "Skipping automatic SVG -> PNG export. Ensure $OutPngPath exists and is a 2048x2048 PNG before running flutter_launcher_icons."
} else {
    Write-Notice "Using Inkscape at: $inkscapeCmd"
    # Export full-size PNG
    $exportCmd = "`"$inkscapeCmd`" `"$SvgPath`" --export-type=png --export-filename=`"$OutPngPath`" --export-width=$Size --export-height=$Size"
    Write-Notice "Running: $exportCmd"
    $ec = & $inkscapeCmd $SvgPath --export-type=png --export-filename=$OutPngPath --export-width=$Size --export-height=$Size
n    if ($LASTEXITCODE -ne 0) {
        Write-Host "Inkscape export failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        exit 2
    }

    Write-Notice "Generated $OutPngPath"

    # Also export a foreground image (transparent background) - reuse same export (SVG usually has transparent background)
    Write-Notice "Exporting foreground image to $ForegroundOut"
    $ec2 = & $inkscapeCmd $SvgPath --export-type=png --export-filename=$ForegroundOut --export-width=$Size --export-height=$Size
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: foreground export failed (exit code $LASTEXITCODE)." -ForegroundColor Yellow
    } else {
        Write-Notice "Generated $ForegroundOut"
    }
}

# Run flutter pub get and flutter_launcher_icons to generate platform icons
Write-Notice "Running flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "flutter pub get failed" -ForegroundColor Red; exit 3 }

Write-Notice "Running flutter_launcher_icons to generate icons"
flutter pub run flutter_launcher_icons:main
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter_launcher_icons failed. Make sure flutter_launcher_icons is in dev_dependencies and flutter_icons config is present in pubspec.yaml." -ForegroundColor Red
    exit 4
}

Write-Notice "Icon generation complete. Rebuild your app to see new icons."
Write-Host "Next: run 'flutter clean' then 'flutter pub get' and build (flutter build apk or flutter build appbundle)" -ForegroundColor Green

