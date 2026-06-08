$ErrorActionPreference = "Stop"

$PluginName = "browser-relay-audio"

Add-Type -AssemblyName System.Windows.Forms

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

function Invoke-Install {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PluginDllPath,
    [Parameter(Mandatory = $true)]
    [string]$UninstallScriptSource,
    [Parameter(Mandatory = $true)]
    [string]$PluginDataSource,
    [Parameter(Mandatory = $true)]
    [string]$ObsRoot
  )

  $resolvedDll = (Resolve-Path -LiteralPath $PluginDllPath).Path
  $pluginBinDir = Join-Path $ObsRoot "obs-plugins\64bit"
  $pluginDataDir = Join-Path $ObsRoot "data\obs-plugins\$PluginName"
  $destinationDll = Join-Path $pluginBinDir (Split-Path -Leaf $resolvedDll)

  New-Item -ItemType Directory -Force -Path $pluginBinDir | Out-Null
  New-Item -ItemType Directory -Force -Path $pluginDataDir | Out-Null

  Copy-Item -LiteralPath $resolvedDll -Destination $destinationDll -Force
  Copy-Item -LiteralPath $UninstallScriptSource -Destination (Join-Path $pluginDataDir "uninstall.ps1") -Force

  if (Test-Path -LiteralPath $PluginDataSource) {
    Get-ChildItem -LiteralPath $PluginDataSource -Force | Copy-Item -Destination $pluginDataDir -Recurse -Force
  } elseif (Test-Path -LiteralPath (Join-Path $scriptDir "en-US.ini")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $pluginDataDir "locale") | Out-Null
    Copy-Item -LiteralPath (Join-Path $scriptDir "en-US.ini") -Destination (Join-Path $pluginDataDir "locale\en-US.ini") -Force
  }

  [System.Windows.Forms.MessageBox]::Show(
    "Installed OBS RelayAudio to:`n$destinationDll",
    "OBS RelayAudio",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
  ) | Out-Null
}

function Invoke-Uninstall {
  param(
    [Parameter(Mandatory = $true)]
    [string]$UninstallScriptPath
  )

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $UninstallScriptPath
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
$pluginDataSource = Join-Path $scriptDir "data\obs-plugins\$PluginName"
$obsRoot = Get-ObsRoot

if (-not (Test-Path -LiteralPath $pluginDllPath)) {
  throw "Plugin DLL not found: $pluginDllPath"
}

$choice = [System.Windows.Forms.MessageBox]::Show(
  "Choose an action for OBS RelayAudio.`n`nYes = Install`nNo = Uninstall`nCancel = Exit",
  "OBS RelayAudio",
  [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
  [System.Windows.Forms.MessageBoxIcon]::Question
)

switch ($choice) {
  "Yes" {
    Invoke-Install -PluginDllPath $pluginDllPath -UninstallScriptSource $uninstallScriptSource -PluginDataSource $pluginDataSource -ObsRoot $obsRoot
  }
  "No" {
    Invoke-Uninstall -UninstallScriptPath $uninstallScriptSource
  }
  default {
    exit 0
  }
}
