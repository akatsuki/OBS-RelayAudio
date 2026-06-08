param(
  [Parameter(Mandatory = $true)]
  [string]$PluginDllPath,

  [string]$ObsRoot,

  [string]$PluginName = "browser-relay-audio",

  [string]$UninstallScriptPath,

  [string]$PluginDataSource
)

$ErrorActionPreference = "Stop"

function Resolve-ObsRoot {
  param([string]$RequestedRoot)

  if ($RequestedRoot) {
    if (-not (Test-Path -LiteralPath $RequestedRoot)) {
      throw "OBS root not found: $RequestedRoot"
    }

    return (Resolve-Path -LiteralPath $RequestedRoot).Path
  }

  $candidateRoots = @(
    (Join-Path $env:ProgramFiles "obs-studio"),
    (Join-Path ${env:ProgramFiles(x86)} "obs-studio")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

  if ($candidateRoots.Count -gt 0) {
    return (Resolve-Path -LiteralPath $candidateRoots[0]).Path
  }

  throw "OBS install root not found. Pass -ObsRoot 'C:\Program Files\obs-studio'."
}

if (-not (Test-Path -LiteralPath $PluginDllPath)) {
  throw "Plugin DLL not found: $PluginDllPath"
}

$resolvedDll = (Resolve-Path -LiteralPath $PluginDllPath).Path
$resolvedObsRoot = Resolve-ObsRoot -RequestedRoot $ObsRoot
$scriptDir = Split-Path -Parent $PSCommandPath
$resolvedPluginDataSource = if ($PluginDataSource) { $PluginDataSource } else { Join-Path $scriptDir "data\obs-plugins\$PluginName" }

$pluginBinDir = Join-Path $resolvedObsRoot "obs-plugins\64bit"
$pluginDataDir = Join-Path $resolvedObsRoot "data\obs-plugins\$PluginName"
$destinationDll = Join-Path $pluginBinDir (Split-Path -Leaf $resolvedDll)

New-Item -ItemType Directory -Force -Path $pluginBinDir | Out-Null
New-Item -ItemType Directory -Force -Path $pluginDataDir | Out-Null

Copy-Item -LiteralPath $resolvedDll -Destination $destinationDll -Force

if ($resolvedPluginDataSource -and (Test-Path -LiteralPath $resolvedPluginDataSource)) {
  Get-ChildItem -LiteralPath $resolvedPluginDataSource -Force | Copy-Item -Destination $pluginDataDir -Recurse -Force
} elseif (Test-Path -LiteralPath (Join-Path $scriptDir "en-US.ini")) {
  New-Item -ItemType Directory -Force -Path (Join-Path $pluginDataDir "locale") | Out-Null
  Copy-Item -LiteralPath (Join-Path $scriptDir "en-US.ini") -Destination (Join-Path $pluginDataDir "locale\en-US.ini") -Force
}

if ($UninstallScriptPath) {
  $resolvedUninstallScript = (Resolve-Path -LiteralPath $UninstallScriptPath).Path
  Copy-Item -LiteralPath $resolvedUninstallScript -Destination (Join-Path $pluginDataDir "uninstall.ps1") -Force
}

Write-Host "Installed OBS plugin DLL to $destinationDll"
