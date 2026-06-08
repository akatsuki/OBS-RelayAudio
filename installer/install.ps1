$ErrorActionPreference = "Stop"

$PluginName = "browser-relay-audio"

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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

if (-not (Test-Administrator)) {
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$PSCommandPath`""
  )

  $process = Start-Process powershell.exe -Verb RunAs -ArgumentList $args -PassThru -Wait
  exit $process.ExitCode
}

$scriptDir = Split-Path -Parent $PSCommandPath
$pluginDllPath = Join-Path $scriptDir "browser-relay-audio.dll"
$uninstallScriptSource = Join-Path $scriptDir "uninstall.ps1"
$obsRoot = Get-ObsRoot

if (-not (Test-Path -LiteralPath $pluginDllPath)) {
  throw "Plugin DLL not found: $pluginDllPath"
}

$resolvedDll = (Resolve-Path -LiteralPath $pluginDllPath).Path
$pluginBinDir = Join-Path $obsRoot "obs-plugins\64bit"
$pluginDataDir = Join-Path $obsRoot "data\obs-plugins\$PluginName"
$destinationDll = Join-Path $pluginBinDir (Split-Path -Leaf $resolvedDll)

New-Item -ItemType Directory -Force -Path $pluginBinDir | Out-Null
New-Item -ItemType Directory -Force -Path $pluginDataDir | Out-Null

Copy-Item -LiteralPath $resolvedDll -Destination $destinationDll -Force
Copy-Item -LiteralPath $uninstallScriptSource -Destination (Join-Path $pluginDataDir "uninstall.ps1") -Force

Write-Host "Installed OBS plugin DLL to $destinationDll"
Write-Host "Installed uninstall script to $pluginDataDir"
