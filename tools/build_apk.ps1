<#
  MixNotice APK build helper.
  Enforces one artifact naming scheme so every package is self-describing:

      MixNotice-v<version>-<tag>-<abi>-<mode>[-<yyyyMMdd>].apk

  Examples:
      MixNotice-v1.0.0-fix10-arm64-debug.apk
      MixNotice-v1.0.0-rc1-arm64-release-20261027.apk

  Fields
      version : read from app/pubspec.yaml (e.g. 1.0.0)
      tag     : round / milestone label   fix10 | rc1 | release   (required)
      abi     : arm64 (default) | armv7 | x64 | universal
      mode    : debug | release
      stamp   : optional build date, use -Stamp

  Usage
      .\build_apk.ps1 -Tag fix11
      .\build_apk.ps1 -Tag fix11 -Abi universal -Mode release -Stamp
      .\build_apk.ps1 -Tag fix11 -DryRun          # show name + preflight only

  Notes
      * default is OFFLINE build (Gradle resolves from local cache); pass -Online if
        a dependency really has to be downloaded.
      * TMP/TEMP are redirected to E:\wbtmp when that drive exists, to keep pressure
        off the C: pagefile during Gradle builds.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [ValidateSet('arm64', 'armv7', 'x64', 'universal')][string]$Abi = 'arm64',
    [ValidateSet('debug', 'release')][string]$Mode = 'debug',
    [switch]$Stamp,
    [switch]$Online,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$tools   = $PSScriptRoot
$root    = Split-Path $tools -Parent
$appDir  = Join-Path $root 'app'
$android = Join-Path $appDir 'android'
if (-not (Test-Path -LiteralPath $android)) { throw "android project not found: $android" }

# ---- version ---------------------------------------------------------------
$pubspec = Join-Path $appDir 'pubspec.yaml'
$m = Select-String -Path $pubspec -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
if (-not $m) { throw "cannot read version from $pubspec" }
$ver = $m.Matches[0].Groups[1].Value

# ---- target platform + engine jar preflight --------------------------------
$tp = switch ($Abi) {
    'arm64'     { 'android-arm64' }
    'armv7'     { 'android-arm' }
    'x64'       { 'android-x64' }
    'universal' { 'android-arm,android-arm64,android-x64' }
}
$abiDirs = switch ($Abi) {
    'arm64'     { @('arm64_v8a') }
    'armv7'     { @('armeabi_v7a') }
    'x64'       { @('x86_64') }
    'universal' { @('armeabi_v7a', 'arm64_v8a', 'x86_64') }
}

$gradleHome = $env:GRADLE_USER_HOME
if (-not $gradleHome) { $gradleHome = Join-Path $env:USERPROFILE '.gradle' }
$engineRoot = Join-Path $gradleHome 'caches\modules-2\files-2.1\io.flutter'

$missing = @()
foreach ($d in $abiDirs) {
    $jar = Get-ChildItem -LiteralPath (Join-Path $engineRoot "${d}_${Mode}") -Recurse -File -Filter '*.jar' -ErrorAction SilentlyContinue |
           Where-Object { $_.Length -gt 1MB } | Select-Object -First 1
    if (-not $jar) { $missing += "${d}_${Mode}" }
}

# ---- artifact name ---------------------------------------------------------
$stampTxt = if ($Stamp) { '-' + (Get-Date -Format 'yyyyMMdd') } else { '' }
$name     = "MixNotice-v$ver-$Tag-$Abi-$Mode$stampTxt.apk"
$outPath  = Join-Path $root $name
$task     = if ($Mode -eq 'debug') { 'assembleDebug' } else { 'assembleRelease' }
$srcApk   = Join-Path $appDir "build\app\outputs\flutter-apk\app-$Mode.apk"

Write-Host ''
Write-Host '======== MixNotice build plan ========' -ForegroundColor Cyan
Write-Host ("  version : {0}" -f $ver)
Write-Host ("  tag     : {0}" -f $Tag)
Write-Host ("  abi     : {0}  ({1})" -f $Abi, $tp)
Write-Host ("  mode    : {0}" -f $Mode)
Write-Host ("  offline : {0}" -f (-not $Online))
Write-Host ("  artifact: {0}" -f $name)
if ($missing.Count -gt 0) {
    Write-Host ("  WARN    : engine jar not cached -> {0}" -f ($missing -join ', ')) -ForegroundColor Yellow
    if (-not $Online) {
        Write-Host '            offline build will fail; use -Abi arm64 or add -Online' -ForegroundColor Yellow
    }
}
Write-Host '======================================' -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ''
    Write-Host 'DryRun: nothing built.' -ForegroundColor Green
    exit 0
}
if ($missing.Count -gt 0 -and -not $Online) {
    throw ("engine jar missing for: {0}. Re-run with -Abi arm64 (cache hit) or add -Online." -f ($missing -join ', '))
}

# ---- environment -----------------------------------------------------------
if (Test-Path -LiteralPath 'E:\wbtmp') {
    $env:TMP  = 'E:\wbtmp'
    $env:TEMP = 'E:\wbtmp'
}
if (-not $env:JAVA_HOME -and (Test-Path -LiteralPath 'D:\dev-toos\jdk-17.0.11')) {
    $env:JAVA_HOME = 'D:\dev-toos\jdk-17.0.11'
}

# ---- build -----------------------------------------------------------------
$gArgs = @($task, "-Ptarget-platform=$tp", '--console=plain')
if (-not $Online) { $gArgs += '--offline' }

Push-Location $android
try {
    & '.\gradlew.bat' @gArgs
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($code -ne 0) { throw "gradle $task failed with exit code $code" }
if (-not (Test-Path -LiteralPath $srcApk)) { throw "apk not produced: $srcApk" }

# ---- publish ---------------------------------------------------------------
Copy-Item -LiteralPath $srcApk -Destination $outPath -Force
$fi = Get-Item -LiteralPath $outPath
$sha = (Get-FileHash -LiteralPath $outPath -Algorithm SHA1).Hash

Write-Host ''
Write-Host '======== MixNotice build done ========' -ForegroundColor Green
Write-Host ("  file : {0}" -f $outPath)
Write-Host ("  size : {0:N1} MB" -f ($fi.Length / 1MB))
Write-Host ("  sha1 : {0}" -f $sha)
Write-Host '======================================' -ForegroundColor Green
