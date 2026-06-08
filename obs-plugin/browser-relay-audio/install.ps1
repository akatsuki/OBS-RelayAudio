param(
  [Parameter(Mandatory = $true)]
  [string]$PluginDllPath,

  [string]$ObsRoot
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

$pluginBinDir = Join-Path $resolvedObsRoot "obs-plugins\64bit"
$destinationDll = Join-Path $pluginBinDir (Split-Path -Leaf $resolvedDll)

New-Item -ItemType Directory -Force -Path $pluginBinDir | Out-Null

Copy-Item -LiteralPath $resolvedDll -Destination $destinationDll -Force

Write-Host "Installed OBS plugin DLL to $destinationDll"
