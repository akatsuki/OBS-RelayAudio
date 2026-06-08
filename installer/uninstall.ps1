$ErrorActionPreference = "Stop"

$PluginName = "browser-relay-audio"

function Get-ObsRoot {
  $candidateRoots = @(
    (Join-Path $env:ProgramFiles "obs-studio"),
    (Join-Path ${env:ProgramFiles(x86)} "obs-studio")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

  if ($candidateRoots.Count -gt 0) {
    return (Resolve-Path -LiteralPath $candidateRoots[0]).Path
  }

  throw "OBS install root not found."
}

$obsRoot = Get-ObsRoot
$pluginBinDir = Join-Path $obsRoot "obs-plugins\64bit"
$pluginDataDir = Join-Path $obsRoot "data\obs-plugins\$PluginName"
$pluginDllPath = Join-Path $pluginBinDir "browser-relay-audio.dll"

if (Test-Path -LiteralPath $pluginDllPath) {
  Remove-Item -LiteralPath $pluginDllPath -Force
  Write-Host "Removed $pluginDllPath"
}

if (Test-Path -LiteralPath $pluginDataDir) {
  Remove-Item -LiteralPath $pluginDataDir -Recurse -Force
  Write-Host "Removed $pluginDataDir"
}
