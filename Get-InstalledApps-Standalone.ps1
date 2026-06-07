# Get-InstalledApps - list installed software from the Windows registry (fast, no Win32_Product).
# Free to use, modify, and share under the MIT License. Provided "as is", without warranty.

function Get-InstalledApps {
<#
.SYNOPSIS
    Lists installed software by reading the Windows registry uninstall keys.

.DESCRIPTION
    Returns installed applications from the registry "Uninstall" keys in three
    locations - the 64-bit HKLM hive, the 32-bit HKLM hive (WOW6432Node), and
    the current user's HKCU hive - reporting each app's name, version,
    publisher, and install date.

    It deliberately AVOIDS the Win32_Product WMI class, which is slow and
    triggers an MSI self-repair (consistency check) on every installed product
    just by being queried. Reading the registry is fast and side-effect free.

    System components and update entries are skipped so the list matches what
    you'd see in "Apps & features". The function is fully self-contained (no
    external dependencies) and safe to run under Set-StrictMode -Version Latest.

.PARAMETER Name
    Optional wildcard filter matched against the application's display name,
    e.g. -Name '*Chrome*'. If omitted, all named applications are returned.

.EXAMPLE
    Get-InstalledApps

    Lists every installed application for the machine and the current user.

.EXAMPLE
    Get-InstalledApps -Name '*office*' | Sort-Object Name

    Finds installed Office-related products.

.EXAMPLE
    Get-InstalledApps | Sort-Object InstallDate -Descending | Select-Object -First 10

    Shows the ten most recently installed applications.
#>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string] $Name
    )

    # StrictMode-safe property reader: returns $null when the property is absent,
    # so registry keys missing a value never cause an error.
    function Get-RegValue {
        param($Key, $PropertyName)
        if ($Key.PSObject.Properties[$PropertyName]) { $Key.$PropertyName } else { $null }
    }

    # Registry uninstall locations: 64-bit HKLM, 32-bit HKLM (WOW6432Node), HKCU.
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = foreach ($path in $paths) {
        # A path may not exist (e.g. WOW6432Node on 32-bit Windows). -Ignore
        # suppresses the error AND keeps it out of $Error.
        $keys = Get-ItemProperty -Path $path -ErrorAction Ignore
        foreach ($key in $keys) {
            $displayName = Get-RegValue $key 'DisplayName'
            if ([string]::IsNullOrWhiteSpace($displayName)) { continue }

            # Skip system components and update entries to keep the list clean.
            if ((Get-RegValue $key 'SystemComponent') -eq 1) { continue }
            if (Get-RegValue $key 'ParentKeyName') { continue }

            # Parse InstallDate (stored as yyyymmdd) into a DateTime where possible.
            # TryParseExact never throws, so a malformed value won't touch $Error.
            $installDate = $null
            $rawDate = Get-RegValue $key 'InstallDate'
            if ($rawDate -match '^\d{8}$') {
                $parsed = [datetime]::MinValue
                if ([datetime]::TryParseExact([string]$rawDate, 'yyyyMMdd', $null,
                        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                    $installDate = $parsed
                }
            }

            [pscustomobject]@{
                Name        = $displayName.Trim()
                Version     = Get-RegValue $key 'DisplayVersion'
                Publisher   = Get-RegValue $key 'Publisher'
                InstallDate = $installDate
            }
        }
    }

    # De-duplicate (an app can register in more than one hive) and apply the filter.
    $results = $results | Sort-Object Name, Version -Unique
    if ($PSBoundParameters.ContainsKey('Name') -and $Name) {
        $results = $results | Where-Object { $_.Name -like $Name }
    }
    $results | Sort-Object Name
}
