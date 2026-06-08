param(
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

$resolvedObsRoot = Resolve-ObsRoot -RequestedRoot $ObsRoot
$pluginBinDir = Join-Path $resolvedObsRoot "obs-plugins\64bit"
$pluginDllPath = Join-Path $pluginBinDir "browser-relay-audio.dll"

if (Test-Path -LiteralPath $pluginDllPath) {
  Remove-Item -LiteralPath $pluginDllPath -Force
  Write-Host "Removed $pluginDllPath"
}
