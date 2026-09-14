[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RockBinPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$rockReferences = (Resolve-Path $RockBinPath).Path
foreach ($name in @('Rock.dll', 'EntityFramework.dll')) {
    if (-not (Test-Path (Join-Path $rockReferences $name) -PathType Leaf)) {
        throw "Missing $name in $rockReferences"
    }
}

Get-Command dotnet -ErrorAction Stop | Out-Null
$project = Join-Path $repoRoot 'src/rocks.derekmaxson.WifiPresence/rocks.derekmaxson.WifiPresence.csproj'
& dotnet build $project --configuration Release "-p:RockBinPath=$rockReferences"
if ($LASTEXITCODE -ne 0) { throw 'Plugin assembly build failed; no package was produced.' }

$assembly = Join-Path $repoRoot 'src/rocks.derekmaxson.WifiPresence/bin/Release/net472/rocks.derekmaxson.WifiPresence.dll'
if (-not (Test-Path $assembly -PathType Leaf)) { throw 'Compiled plugin assembly was not found.' }

$artifactRoot = Join-Path $repoRoot 'artifacts'
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$stage = Join-Path $artifactRoot ('package-' + [Guid]::NewGuid().ToString('N'))
$pluginFiles = Join-Path $stage 'Plugins/WifiPresence'
$assemblyFiles = Join-Path $stage 'bin'
New-Item -ItemType Directory -Path $pluginFiles, $assemblyFiles -Force | Out-Null
try {
    foreach ($name in @('CaptivePortal.ascx', 'CaptivePortal.ascx.cs')) {
        Copy-Item (Join-Path $repoRoot "src/Plugins/WifiPresence/$name") $pluginFiles
    }
    Copy-Item $assembly $assemblyFiles
    $zip = Join-Path $artifactRoot 'WifiPresence-0.1.0.zip'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
    Write-Host "Created $zip"
    Write-Host 'Deploy the Plugins folder first, then bin. Rock runs the page migration on startup.'
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
