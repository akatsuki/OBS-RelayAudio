param(
  [string]$ObsVersion = "32.1.2",
  [string]$BuildDir = "$PSScriptRoot\..\build\obs-plugin\browser-relay-audio",
  [string]$StageDir = "$PSScriptRoot\..\dist\obs-plugin\browser-relay-audio",
  [string]$CacheDir = "$PSScriptRoot\..\build\cache\obs-plugin",
  [string]$ObsInstallRoot = "C:\Program Files\obs-studio"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$pluginSourceDir = Join-Path $repoRoot "obs-plugin\browser-relay-audio"
$cmakeExe = "C:\Program Files\CMake\bin\cmake.exe"
$vsLibExe = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\lib.exe"
$vsDumpbinExe = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\dumpbin.exe"
$sourceZip = Join-Path $CacheDir "OBS-Studio-$ObsVersion.zip"
$sourceDir = Join-Path $CacheDir "obs-studio-$ObsVersion"
$generatedIncludeDir = Join-Path $CacheDir "generated-include"
$generatedObsConfigDir = Join-Path $generatedIncludeDir "libobs"
$obsLibDir = Join-Path $CacheDir "obs-runtime"
$obsImportLib = Join-Path $obsLibDir "obs.lib"
$obsDef = Join-Path $obsLibDir "obs.def"

function Write-TextIfChanged {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Content,
    [Parameter(Mandatory = $true)]
    [string]$Encoding
  )

  if (Test-Path -LiteralPath $Path) {
    $existing = Get-Content -LiteralPath $Path -Raw
    if ($existing -eq $Content) {
      return
    }
  }

  Set-Content -LiteralPath $Path -Value $Content -Encoding $Encoding
}

function Write-ObsConfig {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Version
  )

  $parts = $Version.Split(".")
  if ($parts.Count -ne 3) {
    throw "Unexpected OBS version format: $Version"
  }

  $major = [int]$parts[0]
  $minor = [int]$parts[1]
  $patch = [int]$parts[2]

  $content = @"
#pragma once

#define LIBOBS_API_MAJOR_VER $major
#define LIBOBS_API_MINOR_VER $minor
#define LIBOBS_API_PATCH_VER $patch

#define MAKE_SEMANTIC_VERSION(major, minor, patch) \
  ((major << 24) | (minor << 16) | patch)

#define LIBOBS_API_VER \
  MAKE_SEMANTIC_VERSION(LIBOBS_API_MAJOR_VER, LIBOBS_API_MINOR_VER, LIBOBS_API_PATCH_VER)

#define OBS_VERSION "$Version"
#define OBS_DATA_PATH "../../data"
#define OBS_INSTALL_PREFIX ""
#define OBS_PLUGIN_DESTINATION "obs-plugins"
#define OBS_RELATIVE_PREFIX "../../"
#define OBS_RELEASE_CANDIDATE 0
#define OBS_BETA 0
"@

  Write-TextIfChanged -Path $Path -Content $content -Encoding UTF8
}

function Build-ObsImportLib {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ObsInstallRoot,
    [Parameter(Mandatory = $true)]
    [string]$DumpbinExe,
    [Parameter(Mandatory = $true)]
    [string]$LibExe,
    [Parameter(Mandatory = $true)]
    [string]$OutputDef,
    [Parameter(Mandatory = $true)]
    [string]$OutputLib
  )

  $obsDll = Join-Path $ObsInstallRoot "bin\64bit\obs.dll"
  if (-not (Test-Path -LiteralPath $obsDll)) {
    throw "obs.dll not found at $obsDll"
  }

  if ((Test-Path -LiteralPath $OutputLib) -and (Test-Path -LiteralPath $OutputDef)) {
    $obsDllTime = (Get-Item -LiteralPath $obsDll).LastWriteTimeUtc
    $outputLibTime = (Get-Item -LiteralPath $OutputLib).LastWriteTimeUtc
    $outputDefTime = (Get-Item -LiteralPath $OutputDef).LastWriteTimeUtc
    if ($outputLibTime -ge $obsDllTime -and $outputDefTime -ge $obsDllTime) {
      return
    }
  }

  $exports = & $DumpbinExe /exports $obsDll
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin.exe failed with exit code $LASTEXITCODE"
  }
  if (-not $exports) {
    throw "Failed to read exports from obs.dll"
  }

  $symbols = @()
  $capture = $false
  foreach ($line in $exports) {
    if ($line -match '^\s*ordinal\s+hint\s+RVA\s+name\s*$') {
      $capture = $true
      continue
    }
    if (-not $capture) {
      continue
    }

    $match = [regex]::Match($line, '^\s*\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+([^\s=]+)\s*=')
    if ($match.Success) {
      $name = $match.Groups[1].Value
      if ($name -notmatch '^__imp_' -and $name -notmatch '^@') {
        $symbols += $name
      }
    }
  }

  if ($symbols.Count -eq 0) {
    throw "No exports were parsed from obs.dll."
  }

  $defLines = @(
    "LIBRARY obs",
    "EXPORTS"
  ) + ($symbols | ForEach-Object { "  $_" })
  Set-Content -LiteralPath $OutputDef -Value $defLines -Encoding ASCII

  & $LibExe /nologo /def:$OutputDef /out:$OutputLib /machine:x64
  if ($LASTEXITCODE -ne 0) {
    throw "lib.exe failed with exit code $LASTEXITCODE"
  }
}

function Assert-LastExitCode {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Step
  )

  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

if (-not (Test-Path -LiteralPath $cmakeExe)) {
  throw "CMake not found at $cmakeExe"
}

if (-not (Test-Path -LiteralPath $vsLibExe) -or -not (Test-Path -LiteralPath $vsDumpbinExe)) {
  throw "MSVC tooling not found. Install Visual Studio Build Tools with the C++ toolset."
}

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
New-Item -ItemType Directory -Force -Path $generatedObsConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $obsLibDir | Out-Null

if (-not (Test-Path -LiteralPath $sourceDir)) {
  if (-not (Test-Path -LiteralPath $sourceZip)) {
    $sourceUrl = "https://github.com/obsproject/obs-studio/archive/refs/tags/$ObsVersion.zip"
    Invoke-WebRequest -Uri $sourceUrl -OutFile $sourceZip
  }

  Expand-Archive -LiteralPath $sourceZip -DestinationPath $CacheDir -Force
}

if (-not (Test-Path -LiteralPath $sourceDir)) {
  throw "Failed to extract OBS Studio source archive."
}

Write-ObsConfig -Path (Join-Path $generatedObsConfigDir "obs-config.h") -Version $ObsVersion
Write-TextIfChanged -Path (Join-Path $generatedIncludeDir "obsconfig.h") -Content "#pragma once`r`n" -Encoding ASCII

Build-ObsImportLib `
  -ObsInstallRoot $ObsInstallRoot `
  -DumpbinExe $vsDumpbinExe `
  -LibExe $vsLibExe `
  -OutputDef $obsDef `
  -OutputLib $obsImportLib

$configureArgs = @(
  "-S", $pluginSourceDir,
  "-B", $BuildDir,
  "-A", "x64",
  "-DBRS_OBS_SDK_ROOT=$sourceDir",
  "-DBRS_OBS_CONFIG_DIR=$generatedIncludeDir",
  "-DBRS_OBS_IMPORT_LIB=$obsImportLib"
)

& $cmakeExe @configureArgs
Assert-LastExitCode -Step "CMake configure"
& $cmakeExe --build $BuildDir --config RelWithDebInfo
Assert-LastExitCode -Step "CMake build"
& $cmakeExe --install $BuildDir --config RelWithDebInfo --prefix $StageDir
Assert-LastExitCode -Step "CMake install"

Write-Host "OBS plugin staged at: $StageDir"
