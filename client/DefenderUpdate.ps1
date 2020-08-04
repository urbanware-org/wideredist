# ==========================================================================================================
# WiDeRedist - Windows Defender definition download and redistribution tool
# Local definition update script for Windows servers and clients
# Copyright (C) 2020 by Ralf Kilian and Simon Gauer
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# GitLab: https://gitlab.com/urbanware-org/wideredist
# ==========================================================================================================

$Version = "1.4.0-3"
$TimeStamp = "2020-08-04"

Function Check-Update() {
    Try {
        Invoke-WebRequest -Uri "http://$DefinitionHostSource/version.dat" -OutFile "$VersionFile"
    } Catch [System.Exception] { }

    If ([System.IO.File]::Exists($VersionFile)) {
        $VersionLatest = Get-Content "$VersionFile"
        $VersionUpdate = $False

        If ($Version -eq $VersionLatest -Or $Version.Contains("-")) {
            Return
        }

        $VersionMajor = $Version.Split(".")[0]
        $VersionMinor = $Version.Split(".")[1]
        $VersionRevis = $Version.Split(".")[2]

        $VersionLatestMajor = $VersionLatest.Split(".")[0]
        $VersionLatestMinor = $VersionLatest.Split(".")[1]
        $VersionLatestRevis = $VersionLatest.Split(".")[2]

        If ($VersionLatestMajor -ge $VersionMajor) {
            If ($VersionLatestMajor -gt $VersionMajor) {
                $VersionUpdate = $True
            } Else {
                If ($VersionLatestMinor -ge $VersionMinor) {
                    If ($VersionLatestMinor -gt $VersionMinor) {
                        $VersionUpdate = $True
                    } Else {
                        If ($VersionLatestRevis -ge $VersionRevis) {
                            If ($VersionLatestRevis -gt $VersionRevis) {
                                $VersionUpdate = $True
                            }
                        }
                    }
                }
            }
        }
    }

    If ($VersionUpdate -eq $True) {
        Write-Host
        Write-Host "Please update" -NoNewLine
        Write-Host -ForegroundColor Yellow " WiDeRedist " -NoNewLine
        Write-Host "as version" -NoNewLine
        Write-Host -ForegroundColor Yellow " $VersionLatest " -NoNewLine
        Write-Host "is available now."
        $ExitDelay = $WaitOnError
        Write-Event-Info 101 "New WiDeRedist version ($VersionLatest) available."
    }
}

Function Exit-Script([Int]$ExitCode, [Int]$ExitDelay) {
    $Space = "    "
    $WideSpace = $Space * 10

    Write-Host
    # In case the script is being executed outside an already open PowerShell window (e.g. via
    # shortcut), use a delay to prevent the window from disappearing immediately
    For ($Count = $ExitDelay; $Count -gt 0; $Count--) {
        If ($Count -eq 1) {
            $Seconds = "second"
        } Else {
            $Seconds = "seconds"
        }
        Write-Host -ForegroundColor Cyan "Waiting $Count $Seconds to exit.$Space`r" -NoNewLine
        Start-Sleep -Seconds 1
    }
    Write-Host -ForegroundColor Cyan "Exiting.$WideSpace"
    Write-Host
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
        Write-Event-Warn 131 "Definition file download failed for `"$FileDestination`"."
        $Script:DownloadErrors += 1
    }
}

Function Read-Config([String]$ConfigKey, [String]$Fallback) {
    If (!$ScriptConfigFileExists) {
        Return $Fallback
    }

    # This is not really an INI-file parser, rather a quick-and-dirty solution
    $KeyLine = Get-Content -Path $ScriptConfigFile `
               | Where-Object { $_ -match "$ConfigKey = " }
    If ($null -eq $KeyLine) {
        Write-Event-Warn 121 "No value for config key `"$ConfigKey`". Falling back to default value."
        Return $Fallback
    }
    Return $KeyLine.Split("=")[1].Trim()
}

Function Write-Event($EventLogEntryType, [Int]$EventID, [String]$Message) {
    Write-EventLog -LogName Application -Source "WiDeRedist" -Message $Message -EventID $EventID `
                   -EntryType $EventLogEntryType -Category 0
}

Function Write-Event-Error([Int]$EventID, [String]$Message) {
    Write-Event Error $EventID "$Message"
}

Function Write-Event-Info([Int]$EventID, [String]$Message) {
    Write-Event Information $EventID "$Message"
}

Function Write-Event-Warn([Int]$EventID, [String]$Message) {
    Write-Event Warning $EventID "$Message"
}

Function Write-Log() {
    # This is only the log file from the last run and will be overwritten again after the next one.
    # The details of the each process step are being written into the Windows event log.

    "WiDeRedist log file from the last run:"            | Out-File $ScriptLogFile
    ""                                                  | Out-File $ScriptLogFile -Append
    "  WiDeRedist version:  $Version ($TimeStamp)"      | Out-File $ScriptLogFile -Append
    ""                                                  | Out-File $ScriptLogFile -Append
    "  Start time:          " + $StartTime.DateTime     | Out-File $ScriptLogFile -Append
    "  End time:            " + $EndTime.DateTime       | Out-File $ScriptLogFile -Append
    "  Elapsed time:        " + $ElapsedTimeString      | Out-File $ScriptLogFile -Append
    "  Computer name:       " + $Env:ComputerName       | Out-File $ScriptLogFile -Append
    "  Executed as (user):  " + $Env:UserName           | Out-File $ScriptLogFile -Append
    "  User domain:         " + $Env:UserDomain         | Out-File $ScriptLogFile -Append
    ""                                                  | Out-File $ScriptLogFile -Append
    If ($ExitCode -eq 0) {
        "  Exit code:           0 (Success)"            | Out-File $ScriptLogFile -Append
    } Else {
        "  Exit code:           $ExitCode (Failure)"    | Out-File $ScriptLogFile -Append
    }
    ""                                                  | Out-File $ScriptLogFile -Append
    "  See the Event Viewer for process details."       | Out-File $ScriptLogFile -Append
    ""                                                  | Out-File $ScriptLogFile -Append
    $("-" * 80)                                         | Out-File $ScriptLogFile -Append

    Try {
        (Get-MpComputerStatus | Out-String).Trim()      | Out-File $ScriptLogFile -Append
    } Catch [System.Exception] {
        "Error while trying to get the Windows Defender status.`n" + `
        "Ensure that Windows is activated and Windows Defender is running." `
                                                        | Out-File $ScriptLogFile -Append
    }
    $("-" * 80)                                         | Out-File $ScriptLogFile -Append
}

# First, check the operating system by reading out the platform property. Alternatively you could
# also check the directory separator char to do this. However, using the platform property makes
# more sense.
$Platform = [System.Environment]::OSVersion.Platform.ToString()
If (!$Platform.StartsWith("Win", "CurrentCultureIgnoreCase")) {
    Write-Host -ForegroundColor Red `
      "This platform is not supported by the WiDeRedist client as it requires Microsoft Windows."
    Exit 1
}

# Prevent the script from running multiple times simultaneously
$RunningInstances = Get-WMIObject -Class Win32_Process | Select CommandLine `
                                                       | Select-String -Pattern "DefenderUpdate.ps1" `
                                                       | Measure-Object
If ($RunningInstances.Count -gt 1) {
    Write-Host "Another instance of " -NoNewline
    Write-Host -ForegroundColor Yellow "WiDeRedist" -NoNewline
    Write-Host " is already running."
    Write-Event-Info 102 "Another instance of WiDeRedist is already running."
    Start-Sleep 3
    Exit 255
}

# Create an event log for WiDeRedist (if not already existing)
If (![System.Diagnostics.EventLog]::SourceExists("WiDeRedist")) {
    New-EventLog -LogName Application -Source "WiDeRedist" | Out-Null
}

# Script related
$StartTime = Get-Date
$DownloadErrors = 0

# Local paths and options
$ScriptPath = Split-Path -Parent $PSCommandPath
$ScriptLogFile = "$ScriptPath\RecentUpdate.log"
$ScriptConfigFile = "$ScriptPath\Update.ini"
If ([System.IO.File]::Exists($ScriptConfigFile)) {
    $ScriptConfigFileExists = $True
} Else {
    $ScriptConfigFileExists = $False
    Write-Event-Warn 129 "Config file `"$ScriptConfigFile`" missing. Falling back to default values."
}

# Binary for the Microsoft Malware Protection Command-Run Utility
$MpCmdRunBin = "C:\Program Files\Windows Defender\mpcmdrun.exe"

$Definitions = Read-Config "DefinitionPath" "C:\Defender"
$RemoveSingleQuotesFromPath = Read-Config "RemoveSingleQuotesFromPath" "0"
If ($RemoveSingleQuotesFromPath -eq 1) {
    # Required in case the path inside the config file is enclosed with single quotes. However, this
    # will also remove all of the single quotes in the path itself (if existing). Due to this, it is
    # recommended to use double quotes for enclosing the string.
    $Definitions = $Definitions.Replace("'", "")
}
$Definitions = $Definitions.Replace("`"", "")
$Definitions_x86 = "$Definitions\x86"
$Definitions_x64 = "$Definitions\x64"
$VersionFile = "$Definitions\version.dat"
$RemoveDefinitionPathOnExit = Read-Config "RemoveDefinitionPathOnExit" "0"

# Network related
$DefinitionHostIP = Read-Config "DefinitionHostIP" "192.168.2.1"
$DefinitionHostPort = Read-Config "DefinitionHostPort" "8080"
$DefinitionHostSource = "${DefinitionHostIP}:$DefinitionHostPort"

# Windows Defender preferences
$SetDefinitionSource = Read-Config "SetDefinitionSource" "1"
$ShowUpdateOutput = Read-Config "ShowUpdateOutput" "0"
$SetPreferenceError = $False

# Delays
$WaitOnSuccess = Read-Config "WaitOnSuccess" "3"
$WaitOnError = Read-Config "WaitOnError" "10"

# Suppressing the shell progress output speeds up the whole process significantly and also takes way
# less CPU load
$ProgressPreference = "SilentlyContinue"

Write-Host
Write-Host -ForegroundColor Yellow `
  "WiDeRedist - Windows Defender definition download and redistribution tool"
Write-Host -ForegroundColor Yellow `
  "Local definition update script for Windows servers and clients"
Write-Host -ForegroundColor Yellow "Version $Version (Released $TimeStamp)"
Write-Host -ForegroundColor Yellow "Copyright (C) 2020 by Ralf Kilian and Simon Gauer"
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
    Write-Host -ForegroundColor Red "All definition downloads have failed. Process canceled."
    Write-Host -ForegroundColor Yellow "Please check your network configuration for accessing the source."
    Write-Event-Error 139 "All definition downloads have failed. Please check your network configuration."

    $ExitCode = -1
    $ExitDelay = 10
} ElseIf ($DownloadErrors -gt 0) {
    Write-Host
    Write-Host -ForegroundColor Yellow "At least one definition file download has failed. Trying to" `
                                       "install the"
    Write-Host -ForegroundColor Yellow "available files. However, this can result in outdated definitions."
    Write-Event-Warn 138 "At least one definition file download has failed. Definitions may be outdated."
}

If ($SetDefinitionSource -eq 1) {
    Try {
        Set-MpPreference -SignatureDefinitionUpdateFileSharesSource "$Definitions"
        Set-MpPreference -SignatureFallbackOrder FileShares
    } Catch [System.Exception] {
        # This does not affect the exit code of this script at all, as it is related to the status
        # of the actual Windows Defender update status
        Write-Host
        Write-Host -ForegroundColor Red "Error while trying to set Windows Defender preferences."
        Write-Host -ForegroundColor Yellow "Ensure that Windows is activated and Windows Defender is" `
                                           "running."
        Write-Host -ForegroundColor Yellow "Proceeding anyway."
        $SetPreferenceError = $True
        Write-Event-Warn 141 "Failed to to set Windows Defender preferences."
    }
}

# If all definition file downloads have failed (see the download error handling code further up)
# triggering a signature update does not make any sense at all
If ($DownloadErrors -lt 8) {
    Write-Host
    Write-Host "Installing definitions. Please wait, this may take a while."

    # Use an external command to update the definitions as the cmdlet called 'Update-MpSignature'
    # did not work properly (not at all to be precise)
    If ($ShowUpdateOutput -eq 1) {
        Write-Host
        Write-Host -ForegroundColor Yellow "> Windows Defender update process output"
        & $MpCmdRunBin -SignatureUpdate -Path "$Definitions"
        Write-Host -ForegroundColor Yellow "< Windows Defender update process exited"
    } Else {
        # Suppress the output
        & $MpCmdRunBin -SignatureUpdate -Path "$Definitions" | Out-Null
    }

    If ($? -eq $True) {
        Write-Host
        Write-Host -ForegroundColor Green `
          "Windows Defender definition update has been successfully completed."
        Write-Host -ForeGroundColor White "See " -NoNewLine
        Write-Host -ForegroundColor Yellow "$ScriptLogFile" -NoNewline
        Write-Host -ForeGroundColor White " for the current status."

        If ($DownloadErrors -gt 0) {
            # In this case, the update process itself was successful, but the download of at least
            # one definition file has failed, which most likely results in outdated definitions
            # (see the download error handling code further up)
            $ExitCode = 2
        } Else {
            $ExitCode = 0
        }
        $ExitDelay = $WaitOnSuccess
    } Else {
        Write-Host
        Write-Host -ForegroundColor Red "Windows Defender definition update has failed."
        Write-Host -ForeGroundColor Yellow "In case the downloads above failed, check the configuration" `
                                           "file. Otherwise"
        Write-Host -ForeGroundColor Yellow "check the Windows Defender and the WiDeRedist log file as" `
                                           "well as its log"
        Write-Host -ForeGroundColor Yellow "entries inside the Event Viewer."
        If ($ShowUpdateOutput -ne 1) {
            Write-Host
            Write-Host -ForeGroundColor Yellow "You may also set the value of " -NoNewLine
            Write-Host -ForegroundColor White "ShowUpdateOutput" -NoNewline
            Write-Host -ForeGroundColor Yellow " to "  -NoNewLine
            Write-Host -ForegroundColor White "1" -NoNewline
            Write-Host -ForeGroundColor Yellow " inside the WiDeRedist "
            Write-Host -ForegroundColor Yellow "config file to see "  -NoNewLine
            Write-Host -ForeGroundColor Yellow "the output of the Windows Defender update command itself."
        }

        $ExitCode = 1
        $ExitDelay = $WaitOnError
        Write-Event-Error 149 `
          "Windows Defender definition update has failed. Please check the configuration file."
    }
}

# In order to reduce disk usage, you can automatically remove the local definition directory
# created by this script. See local path options inside the config file.
If ($RemoveDefinitionPathOnExit -eq 1) {
    Remove-Item -Path $Definitions -Recurse -Force
}

# Get current timestamp and consequential elapsed time
$EndTime = Get-Date
$ElapsedTimeSpan = New-TimeSpan $StartTime $EndTime
$ElapsedTimeString = $ElapsedTimeSpan.ToString("hh\:mm\:ss")
Write-Host
Write-Host "Elapsed time: $ElapsedTimeString"

# Get update information from the server (if existing)
Check-Update

Write-Log
If ($ExitCode -eq -1) {
    Write-Event-Error 199 (Get-Content $ScriptLogFile -Raw)
} Else {
    Write-Event-Info 100 (Get-Content $ScriptLogFile -Raw)
}
Exit-Script $ExitCode $ExitDelay
