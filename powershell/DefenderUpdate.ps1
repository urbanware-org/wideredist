# ==============================================================================================
# WiDeRedist - Windows Defender definition download and redistribution tool
# Local definition update script for Windows servers and clients
# Copyright (C) 2019 by Ralf Kilian and Simon Gauer
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# ==============================================================================================

$Version = "1.0.4"
$TimeStamp = "2019-04-26"

Function Download-File([String]$FileSource, [String]$FileDestination, [Int]$FileCurrent,
                       [Int]$FileCount) {

    Write-Host "  File '$FileDestination' `t($FileCurrent of $FileCount): " -NoNewline
    Try {
        Invoke-WebRequest -Uri $FileSource -OutFile "$FileDestination"
        Write-Host -ForegroundColor Green "Download completed."
    } Catch [System.Exception] {
        Write-Host -ForegroundColor Red "Download failed."
    }
}

Function Read-Config ([String]$ConfigKey) {
    # This is not really an INI-file parser, rather a quick-and-dirty solution
    $KeyLine = Get-Content -Path "$ScriptPath\Update.ini" `
               | Where-Object { $_ -match "$ConfigKey = " }
    Return $KeyLine.Split("=")[1].Trim()
}

# Local paths and options
$DefenderLogFile = "C:\Users\ADMINI~1\AppData\Local\Temp\MpCmdRun.log"
$ScriptPath = Split-Path -Parent $PSCommandPath
$ScriptLogFile = "$ScriptPath\RecentUpdate.log"
$Definitions = Read-Config "DefinitionPath"
$Definitions_x86 = "$Definitions\x86"
$Definitions_x64 = "$Definitions\x64"
$RemoveDefinitionPathOnExit = Read-Config "RemoveDefinitionPathOnExit"

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

Download-File "http://$DefinitionHostSource/x86/mpam-d.exe"   "$Definitions_x86\mpam-d.exe"   1 8
Download-File "http://$DefinitionHostSource/x86/mpam-fe.exe"  "$Definitions_x86\mpam-fe.exe"  2 8
Download-File "http://$DefinitionHostSource/x86/mpas-fe.exe"  "$Definitions_x86\mpas-fe.exe"  3 8
Download-File "http://$DefinitionHostSource/x86/nis_full.exe" "$Definitions_x86\nis_full.exe" 4 8

Download-File "http://$DefinitionHostSource/x64/mpam-d.exe"   "$Definitions_x64\mpam-d.exe"   5 8
Download-File "http://$DefinitionHostSource/x64/mpam-fe.exe"  "$Definitions_x64\mpam-fe.exe"  6 8
Download-File "http://$DefinitionHostSource/x64/mpas-fe.exe"  "$Definitions_x64\mpas-fe.exe"  7 8
Download-File "http://$DefinitionHostSource/x64/nis_full.exe" "$Definitions_x64\nis_full.exe" 8 8

Write-Host
Write-Host "Installing definitions. Please wait, this may take a while."

# Setting this once should be enough, but what the heck
Set-MpPreference -SignatureDefinitionUpdateFileSharesSources "$Definitions"
Set-MpPreference -SignatureFallbackOrder FileShares

# Use this external command to update the definitions as the cmdlet called
# 'Update-MpSignature' did not work properly (not at all to be precise)
& 'C:\Program Files\Windows Defender\mpcmdrun.exe' -SignatureUpdate `
                                                   -Path "$Definitions" | Out-Null
Write-Host
If ($? -eq $True) {
    Write-Host -ForegroundColor Green "Update successfully completed."
    Write-Host "See '$ScriptLogFile' for the current status."
    $ExitCode = 0
} Else {
    Write-Host -ForegroundColor Red "Update process failed."
    Write-Host -ForegroundColor Red "See '$DefenderLogFile' for details."
    $ExitCode = 1
}

# In order to reduce disk usage, you can automatically remove the local
# definition directory created by this script. See local path options on
# top of this file.
If ($RemoveDefinitionPathOnExit -eq 1) {
    Remove-Item -Path $Definitions -Recurse -Force
}

# Write (or overwrite previous) simple status file (not a log) which
# requires some revision. Also, a detailed log file (or one at all)
# would be nice, but has not been implemented, yet.
Get-Date | Out-File $ScriptLogFile
Get-MpComputerStatus | Out-File $ScriptLogFile -Append

Write-Host
Start-Sleep 3
Exit $ExitCode
