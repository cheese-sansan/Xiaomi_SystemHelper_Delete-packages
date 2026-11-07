[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$AdbPath,
    [string]$ToolDirectory = (Join-Path $env:LOCALAPPDATA 'Qoder\AndroidPlatformTools')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$script:AdbExecutable = $null
$script:PlatformToolsUrl = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'

function Invoke-Adb {
    param([string[]]$Arguments)

    $output = @(& $script:AdbExecutable @Arguments)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "adb $($Arguments -join ' ') exited with code $exitCode."
    }
    return $output
}

function Assert-OneDevice {
    $lines = @(Invoke-Adb -Arguments @('devices'))
    $devices = @($lines | Where-Object { $_ -match '^\S+\s+(device|unauthorized|offline|recovery|sideload|bootloader)\s*$' })
    if ($devices.Count -ne 1) {
        throw "Expected exactly one connected device; found $($devices.Count)."
    }
    if ($devices[0] -notmatch '\sdevice\s*$') {
        throw 'The connected device is unauthorized or not ready.'
    }
}

function Get-CurrentUser {
    $lines = @(Invoke-Adb -Arguments @('shell', 'am', 'get-current-user'))
    $value = ([string]($lines | Select-Object -Last 1)).Trim()
    $userId = 0
    if (-not [int]::TryParse($value, [ref]$userId)) {
        throw "Unable to parse the current Android user from '$value'."
    }
    return $userId
}

function Test-PackagePresent {
    param([string]$Package)

    $output = @(& $script:AdbExecutable shell pm path $Package)
    $exitCode = $LASTEXITCODE
    $paths = @($output | Where-Object { $_ -match '^package:\S+' })
    $unexpected = @($output | Where-Object { $_.Trim().Length -gt 0 -and $_ -notmatch '^package:\S+' })
    if ($unexpected.Count -gt 0) {
        throw "Unexpected pm path output for ${Package}: $($unexpected -join ' ')"
    }
    if ($paths.Count -gt 0) {
        return $true
    }
    if ($exitCode -eq 0 -or $exitCode -eq 1) {
        return $false
    }
    throw "pm path failed for $Package with exit code $exitCode."
}

try {
    if ($AdbPath) {
        if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
            throw "ADB executable not found at '$AdbPath'."
        }
        $script:AdbExecutable = (Resolve-Path -LiteralPath $AdbPath).Path
    } else {
        $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
        $existingAdb = Join-Path $ToolDirectory 'platform-tools\adb.exe'
        if ($null -ne $adbCommand) {
            $script:AdbExecutable = $adbCommand.Source
        } elseif (Test-Path -LiteralPath $existingAdb -PathType Leaf) {
            $script:AdbExecutable = $existingAdb
        } else {
            if ($WhatIfPreference) {
                Write-Host "WHATIF: Download Android Platform-Tools from $script:PlatformToolsUrl"
                Write-Host 'WHATIF: Device checks skipped because ADB is not installed.'
                Write-Host 'WHATIF: No device changes made.'
                return
            }

            New-Item -ItemType Directory -Path $ToolDirectory -Force | Out-Null
            $zipPath = Join-Path $env:TEMP ("platform-tools-{0}.zip" -f [guid]::NewGuid().ToString('N'))
            try {
                Write-Host 'ADB: Downloading official Android Platform-Tools.'
                Invoke-WebRequest -Uri $script:PlatformToolsUrl -OutFile $zipPath
                Expand-Archive -LiteralPath $zipPath -DestinationPath $ToolDirectory -Force
            } finally {
                if (Test-Path -LiteralPath $zipPath) {
                    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
                }
            }
            $script:AdbExecutable = $existingAdb
        }
    }

    if (-not (Test-Path -LiteralPath $script:AdbExecutable -PathType Leaf)) {
        throw 'ADB executable was not found after setup.'
    }

    Write-Host "ADB: $script:AdbExecutable"
    Assert-OneDevice
    Write-Host 'DEVICE: One authorized device connected.'
    $userId = Get-CurrentUser
    Write-Host "USER: $userId"

    $packages = @(
        'com.mobiletools.systemhelper',
        'com.miui.hybrid',
        'com.miui.dmregservice',
        'com.miui.guardprovider'
    )
    $removed = 0
    $alreadyAbsent = 0
    $skipped = 0
    $whatIfCount = 0
    $verified = 0

    foreach ($package in $packages) {
        if (-not (Test-PackagePresent -Package $package)) {
            Write-Host "SKIP: $package is already absent for user $userId."
            $alreadyAbsent++
            $verified++
            continue
        }

        $target = "$package (user $userId)"
        $operation = 'Uninstall without keeping current-user application data'
        if ($PSCmdlet.ShouldProcess($target, $operation)) {
            $result = @(& $script:AdbExecutable shell pm uninstall --user $userId $package)
            $exitCode = $LASTEXITCODE
            $resultText = ($result -join "`n").Trim()
            if ($exitCode -ne 0 -or $resultText -ne 'Success') {
                throw "Uninstall failed for ${Package}: $resultText"
            }
            if (Test-PackagePresent -Package $package) {
                throw "Package path still exists after uninstall: $package"
            }
            Write-Host "OK: $package removed without keeping current-user app data."
            $removed++
            $verified++
        } elseif ($WhatIfPreference) {
            $whatIfCount++
        } else {
            Write-Host "SKIP: $package was not confirmed."
            $skipped++
        }
    }

    Assert-OneDevice
    Write-Host 'BASIC: ADB connection and package path checks passed.'
    Write-Host "SUMMARY: removed=$removed alreadyAbsent=$alreadyAbsent skipped=$skipped whatIf=$whatIfCount verified=$verified backups=0 reboot=no"
    if ($WhatIfPreference) {
        Write-Host 'WHATIF: No device changes made.'
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
