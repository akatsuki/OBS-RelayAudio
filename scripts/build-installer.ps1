param(
  [string]$InstallerName = "OBS-RelayAudio-dev-release-setup.exe",
  [string]$StageDir = "$env:TEMP\obs-relay-audio-installer-stage",
  [string]$OutputDir = "$PSScriptRoot\..\release",
  [string]$SedPath = "$env:TEMP\obs-relay-audio-installer.sed",
  [string]$TempOutputDir = "$env:TEMP\obs-relay-audio-installer-out"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$sourceDll = Join-Path $repoRoot "dist\obs-plugin\browser-relay-audio\obs-plugins\64bit\browser-relay-audio.dll"
$installerDir = Join-Path $repoRoot "installer"
$iexpressExe = "C:\WINDOWS\system32\iexpress.exe"
$tempOutputPath = Join-Path $TempOutputDir $InstallerName
$outputPath = Join-Path $OutputDir $InstallerName

function Write-SedFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$TargetName,
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [Parameter(Mandatory = $true)]
    [string[]]$RelativeFiles
  )

  $fileStringLines = New-Object System.Collections.Generic.List[string]
  $sourceFileLines = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $RelativeFiles.Count; $i++) {
    $fileStringLines.Add("FILE$i=$($RelativeFiles[$i])")
    $sourceFileLines.Add("%FILE$i%=")
  }

  $content = @"
[Version]
Class=IEXPRESS
SEDVersion=3

[Options]
PackagePurpose=InstallApp
ExtractOnly=0
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles

[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$TargetName
FriendlyName=OBS RelayAudio Installer
AppLaunched=install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
$($fileStringLines -join "`r`n")

[SourceFiles]
SourceFiles0=$SourceDir

[SourceFiles0]
$($sourceFileLines -join "`r`n")
"@

  Set-Content -LiteralPath $Path -Value $content -Encoding ASCII
}

function Get-RelativeStagePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BaseDir,
    [Parameter(Mandatory = $true)]
    [string]$FullPath
  )

  $resolvedBase = (Resolve-Path -LiteralPath $BaseDir).Path.TrimEnd('\') + '\'
  $resolvedFull = (Resolve-Path -LiteralPath $FullPath).Path

  if ($resolvedFull.StartsWith($resolvedBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $resolvedFull.Substring($resolvedBase.Length)
  }

  return Split-Path -Leaf $resolvedFull
}

if (-not (Test-Path -LiteralPath $sourceDll)) {
  throw "Built plugin DLL not found at $sourceDll"
}

Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $TempOutputDir -Recurse -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $TempOutputDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SedPath) | Out-Null

Copy-Item -LiteralPath (Join-Path $installerDir "install.cmd") -Destination (Join-Path $StageDir "install.cmd") -Force
Copy-Item -LiteralPath (Join-Path $installerDir "install.ps1") -Destination (Join-Path $StageDir "install.ps1") -Force
Copy-Item -LiteralPath (Join-Path $installerDir "uninstall.ps1") -Destination (Join-Path $StageDir "uninstall.ps1") -Force
Copy-Item -LiteralPath $sourceDll -Destination (Join-Path $StageDir "browser-relay-audio.dll") -Force

$localeSource = Join-Path $repoRoot "dist\obs-plugin\browser-relay-audio\data\obs-plugins\browser-relay-audio\locale\en-US.ini"
if (Test-Path -LiteralPath $localeSource) {
  Copy-Item -LiteralPath $localeSource -Destination (Join-Path $StageDir "en-US.ini") -Force
}

$relativeFiles = Get-ChildItem -LiteralPath $StageDir -File -Recurse | ForEach-Object {
  Get-RelativeStagePath -BaseDir $StageDir -FullPath $_.FullName
} | Sort-Object

if (-not (Test-Path -LiteralPath $iexpressExe)) {
  throw "IExpress not found at $iexpressExe"
}

Write-SedFile -Path $SedPath -TargetName $tempOutputPath -SourceDir $StageDir -RelativeFiles $relativeFiles

& $iexpressExe /N /Q $SedPath
if (-not (Test-Path -LiteralPath $tempOutputPath)) {
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    if (Test-Path -LiteralPath $tempOutputPath) {
      break
    }
  }
}

if (-not (Test-Path -LiteralPath $tempOutputPath)) {
  throw "IExpress failed with exit code $LASTEXITCODE"
}

Copy-Item -LiteralPath $tempOutputPath -Destination $outputPath -Force

Write-Host "Installer created at: $outputPath"
