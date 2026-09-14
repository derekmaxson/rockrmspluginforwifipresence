#requires -Version 5.1
#requires -PSEdition Desktop
# Run in Windows PowerShell to use the same System.Web implementation as Rock v19.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$source = Get-Content (Join-Path $repoRoot 'src/Plugins/WifiPresence/CaptivePortal.ascx.cs') -Raw
$match = [regex]::Match($source, '(?s)#region Release URL helpers\s*(.*?)#endregion')
if (-not $match.Success) { throw 'Release URL helper region not found.' }

# Compile the actual production helpers, not a separately implemented URL algorithm.
if (-not ('WifiReleaseUrlTests' -as [type])) {
    $code = @"
using System;
using System.Linq;
using System.Collections.Specialized;
using System.Web;
public static class WifiReleaseUrlTests {
    $($match.Groups[1].Value)
    public static bool Accepts(string query) {
        Uri target;
        return TryGetReleaseUri(HttpUtility.ParseQueryString(query), out target);
    }
    public static string Redirect(string query, int? alias) {
        var parameters = HttpUtility.ParseQueryString(query);
        Uri target;
        if (!TryGetReleaseUri(parameters, out target)) throw new ArgumentException("Invalid release URL");
        return BuildReleaseUrl(parameters["fppostback"], query, alias);
    }
}
"@
    Add-Type -TypeDefinition $code -ReferencedAssemblies System.dll, System.Core.dll, System.Web.dll
}

function Assert-Equal($actual, $expected, [string] $label) {
    if ($actual -cne $expected) { throw "$label : expected [$expected], got [$actual]" }
}
function Get-Query([string] $callback) {
    return 'client_mac=02%3A11%3A22%3A33%3A44%3A55&fppostback=' + [System.Web.HttpUtility]::UrlEncode($callback)
}

foreach ($callback in @('https://wifi.example/connect', 'http://192.0.2.1:8080/release')) {
    Assert-Equal ([WifiReleaseUrlTests]::Accepts((Get-Query $callback))) $true "Valid URL $callback"
}
foreach ($callback in @('', '/relative', '//wifi.example/release', 'javascript:alert(1)',
    'ftp://wifi.example/release', 'https://user:password@wifi.example/release',
    "https://wifi.example/release`r`nInjected: yes", 'https://wifi.example\release')) {
    Assert-Equal ([WifiReleaseUrlTests]::Accepts((Get-Query $callback))) $false "Invalid URL $callback"
}
Assert-Equal ([WifiReleaseUrlTests]::Accepts('client_mac=021122334455')) $false 'Missing fppostback'
Assert-Equal ([WifiReleaseUrlTests]::Accepts('fppostback=https%3A%2F%2Fa.example&fppostback=https%3A%2F%2Fb.example')) $false 'Duplicate fppostback'

$callback = 'https://wifi.example/release?token=a%2Bb%26c%3Dd&id=999#complete'
$query = (Get-Query $callback) + '&id=888&tag=one&tag=two'
$rawRedirect = [WifiReleaseUrlTests]::Redirect($query, 42)
Assert-Equal $rawRedirect ('https://wifi.example/release?token=a%2Bb%26c%3Dd&id=999&' + $query + '&id=42#complete') 'Exact callback and incoming query preservation'
$redirect = [Uri] $rawRedirect
$parameters = [System.Web.HttpUtility]::ParseQueryString($redirect.Query)
Assert-Equal $redirect.Host 'wifi.example' 'Callback host'
Assert-Equal $redirect.AbsolutePath '/release' 'Callback path'
Assert-Equal $redirect.Fragment '#complete' 'Fragment retained'
Assert-Equal $parameters['token'] 'a+b&c=d' 'Nested query encoding'
Assert-Equal $parameters['client_mac'] '02:11:22:33:44:55' 'MAC forwarding'
Assert-Equal $parameters['fppostback'] $callback 'Original callback forwarded'
Assert-Equal ($parameters.GetValues('id')[-1]) '42' 'Resolved alias appended as id'
Assert-Equal ($parameters.GetValues('id') -join ',') '999,888,42' 'Existing id values retained before appended alias'
Assert-Equal ($parameters.GetValues('tag') -join ',') 'one,two' 'Repeated parameters retained'

$anonymous = [Uri] [WifiReleaseUrlTests]::Redirect((Get-Query 'https://wifi.example/release'), $null)
$parameters = [System.Web.HttpUtility]::ParseQueryString($anonymous.Query)
Assert-Equal $parameters['id'] $null 'Anonymous redirect does not invent an alias'
# A second request must use its own callback, not any remembered or configured URL.
$other = [Uri] [WifiReleaseUrlTests]::Redirect((Get-Query 'https://other.example/connect'), 7)
Assert-Equal $other.Host 'other.example' 'Per-request callback'
# Compare literal strings, rather than decoded values, for the intact-query contract.
$raw = 'client_mac=02%3a11%3A22%3a33%3A44%3a55&space=a+b&space=a%20b&flag&empty=&tag=1&tag=2&token=%252f&fppostback=https%3A%2F%2Fwifi.example%2Frelease'
Assert-Equal ([WifiReleaseUrlTests]::Redirect($raw, 123)) ('https://wifi.example/release?' + $raw + '&id=123') 'Raw encoding, order, duplicates, and empty values retained'
Assert-Equal ([WifiReleaseUrlTests]::Redirect($raw, $null)) ('https://wifi.example/release?' + $raw) 'Anonymous query returned intact'
Assert-Equal ([WifiReleaseUrlTests]::Redirect(($raw + '&id=old'), 123)) ('https://wifi.example/release?' + $raw + '&id=old&id=123') 'Append-only behavior preserves existing id'
foreach ($callback in @('https://wifi.example/release?', 'https://wifi.example/release?token=x&')) {
    $raw = Get-Query $callback
    Assert-Equal ([WifiReleaseUrlTests]::Redirect($raw, 123)) ($callback + $raw + '&id=123') 'Existing query separator retained'
}
Write-Host 'Release URL tests passed.'
