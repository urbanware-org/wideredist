# ==============================================================================================
# WiDeRedist - Windows Defender definition download and redistribution tool
# Local definition update script for Windows servers and clients
# Copyright (C) 2019 by Ralf Kilian and Simon Gauer
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# GitLab: https://gitlab.com/urbanware-org/wideredist
# ==============================================================================================

$Version = "1.0.6"
$TimeStamp = "2019-07-11"

Function Exit-Script([Int]$ExitCode, [Int]$SleepTime) {
    # In case the script is being executed outside a PowerShell window,
    # use a delay to prevent the window from disappearing immediately
    Write-Host
    Write-Host -ForegroundColor Cyan "Waiting $SleepTime seconds to exit."
    Write-Host
    Start-Sleep $SleepTime
    Exit $ExitCode
}

Function Get-Definition-File([String]$FileSource, [String]$FileDestination, [Int]$FileCurrent,
                             [Int]$FileCount) {
    Write-Host "  File '$FileDestination' `t($FileCurrent of $FileCount): " -NoNewline
    Try {
        Invoke-WebRequest -Uri $FileSource -OutFile "$FileDestination"
        Write-Host -ForegroundColor Green "Download completed."
    } Catch [System.Exception] {
        Write-Host -ForegroundColor Red "Download failed."
        $DownloadErrors += 1
    }
}

Function Read-Config([String]$ConfigKey, [String]$Fallback) {
    # This is not really an INI-file parser, rather a quick-and-dirty solution
    $KeyLine = Get-Content -Path "$ScriptPath\Update.ini" `
               | Where-Object { $_ -match "$ConfigKey = " }
    If ($null -eq $KeyLine) {
        Return $Fallback
    }
    Return $KeyLine.Split("=")[1].Trim()
}

Function Write-Log() {
    "WiDeRedist log file"                               | Out-File $ScriptLogFile
    ""                                                  | Out-File $ScriptLogFile -Append
    "  WiDeRedist version:  $Version ($TimeStamp)"      | Out-File $ScriptLogFile -Append
    ""                                                  | Out-File $ScriptLogFile -Append
    "  Start time:          " + $StartTime.DateTime     | Out-File $ScriptLogFile -Append
    "  End time:            " + $EndTime.DateTime       | Out-File $ScriptLogFile -Append
    "  Elapsed time:        " + $ElapsedTime            | Out-File $ScriptLogFile -Append
    ""                                                  | Out-File $ScriptLogFile -Append
    If ($ExitCode -eq 0) {
        "  Exit code:           0 (Success)"            | Out-File $ScriptLogFile -Append
    } Else {
        "  Exit code:           $ExitCode (Failure)"    | Out-File $ScriptLogFile -Append
    }
    ""                                                  | Out-File $ScriptLogFile -Append
    $("-" * 80)                                         | Out-File $ScriptLogFile -Append
    (Get-MpComputerStatus | Out-String).Trim()          | Out-File $ScriptLogFile -Append
    $("-" * 80)                                         | Out-File $ScriptLogFile -Append
}

# Script related
$StartTime = Get-Date
$DownloadErrors = 0

# Local paths and options
$ScriptPath = Split-Path -Parent $PSCommandPath
$ScriptLogFile = "$ScriptPath\RecentUpdate.log"
$Definitions = Read-Config "DefinitionPath"
$Definitions_x86 = "$Definitions\x86"
$Definitions_x64 = "$Definitions\x64"
$RemoveDefinitionPathOnExit = Read-Config "RemoveDefinitionPathOnExit" "0"

# Network related
$DefinitionHostIP = Read-Config "DefinitionHostIP"
$DefinitionHostPort = Read-Config "DefinitionHostPort"
$DefinitionHostSource = "${DefinitionHostIP}:$DefinitionHostPort"

# Suppressing the shell progress output speeds up the whole process
# significantly and also takes way less CPU load
$ProgressPreference = "SilentlyContinue"

Write-Host
Write-Host -ForegroundColor Yellow `
    "WiDeRedist - Windows Defender definition download and redistribution tool"
Write-Host -ForegroundColor Yellow `
    "Local definition update script for Windows servers and clients"
Write-Host -ForegroundColor Yellow "Version $Version ($TimeStamp)"
Write-Host -ForegroundColor Yellow "Copyright (C) 2019 by Ralf Kilian and Simon Gauer"
Write-Host
Write-Host "Downloading definitions from update source."

# Before downloading anything, ensure the target directories exist
New-Item -ItemType Directory -Path $Definitions     -Force | Out-Null
New-Item -ItemType Directory -Path $Definitions_x86 -Force | Out-Null
New-Item -ItemType Directory -Path $Definitions_x64 -Force | Out-Null

Get-Definition-File "http://$DefinitionHostSource/x86/mpam-d.exe"   "$Definitions_x86\mpam-d.exe"   1 8
Get-Definition-File "http://$DefinitionHostSource/x86/mpam-fe.exe"  "$Definitions_x86\mpam-fe.exe"  2 8
Get-Definition-File "http://$DefinitionHostSource/x86/mpas-fe.exe"  "$Definitions_x86\mpas-fe.exe"  3 8
Get-Definition-File "http://$DefinitionHostSource/x86/nis_full.exe" "$Definitions_x86\nis_full.exe" 4 8

Get-Definition-File "http://$DefinitionHostSource/x64/mpam-d.exe"   "$Definitions_x64\mpam-d.exe"   5 8
Get-Definition-File "http://$DefinitionHostSource/x64/mpam-fe.exe"  "$Definitions_x64\mpam-fe.exe"  6 8
Get-Definition-File "http://$DefinitionHostSource/x64/mpas-fe.exe"  "$Definitions_x64\mpas-fe.exe"  7 8
Get-Definition-File "http://$DefinitionHostSource/x64/nis_full.exe" "$Definitions_x64\nis_full.exe" 8 8

If ($DownloadErrors -eq 8) {
    Write-Host
    Write-Host -ForegroundColor Red `
        "All definition downloads have failed. Process canceled."
    Write-Host -ForegroundColor Yellow `
        "Please check your network configuration for accessing the source."
    Exit-Script 1 10
} ElseIf ($DownloadErrors -gt 0) {
    Write-Host
    Write-Host -ForegroundColor Yellow `
        "At least one download has failed. Trying to install available files."
    Write-Host -ForegroundColor Yellow `
        "However, this can result in outdated definitions."
}

Write-Host
Write-Host "Installing definitions. Please wait, this may take a while."

# Setting this once should be enough, but what the heck
Set-MpPreference -SignatureDefinitionUpdateFileSharesSources "$Definitions"
Set-MpPreference -SignatureFallbackOrder FileShares

# Use this external command to update the definitions as the cmdlet called
# 'Update-MpSignature' did not work properly (not at all to be precise)
& 'C:\Program Files\Windows Defender\mpcmdrun.exe' -SignatureUpdate `
                                                   -Path "$Definitions" | Out-Null
If ($? -eq $True) {
    Write-Host
    Write-Host -ForegroundColor Green `
        "Windows Defender definition update has been successfully completed."
    Write-Host "See '$ScriptLogFile' for the current status."
    $ExitCode = 0
    $SleepTime = 3
} Else {
    Write-Host
    Write-Host -ForegroundColor Red `
        "Windows Defender definition update has failed."
    Write-Host -ForeGroundColor Yellow `
        "In case the downloads above failed, check the configuration file."
    Write-Host -ForeGroundColor Yellow `
        "Otherwise, see the Windows Defender logs inside the Event Viewer"
    Write-Host -ForegroundColor Yellow `
        "for details."
    $ExitCode = 1
    $SleepTime = 10
}

# In order to reduce disk usage, you can automatically remove the local
# definition directory created by this script. See local path options on
# top of this file.
If ($RemoveDefinitionPathOnExit -eq 1) {
    Remove-Item -Path $Definitions -Recurse -Force
}

# Get timestamp and elapsed time
$EndTime = Get-Date
$ElapsedTime = New-TimeSpan $StartTime $EndTime

# Write (overwrite previous) the log file (which still requires some revision)
Write-Log

Write-Host
Start-Sleep $SleepTime
Exit $ExitCode
