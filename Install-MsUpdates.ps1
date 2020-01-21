﻿<#PSScriptInfo

.VERSION 1.0

.GUID e00eab9b-d7d9-4cf3-a14f-8b14daf0545e

.AUTHOR Erik Whitesides

.COPYRIGHT 2019

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
#>

<#
.SYNOPSIS
Script to issue a windows or microsoft update job to remote machines.

.DESCRIPTION
Script does the following:
-installs the Nuget package provider
-installs PSWindowsupdate module from psgallery
-builds the update command
-sends the update command to the remote computer
-the update command tells the remote machine to run Invoke-WUJob on itself
-Invoke-WUJob then creates a Scheduled Task called PSWindowsUpdate and configures the job as the SYSTEM user.
-By doing it this way we can bypass the need to run Enable-WURemoting and expose additional ports/change settings.

.PARAMETER ComputerName
The name of one or more computers to send the update job to.

.PARAMETER Now
Switch to indicate that the update process start immediately.

.PARAMETER At
Parameter to indicate the time at which to start the update process.
Takes a [datetime] object. Validation ensures it is in the future.

.EXAMPLE
.\Install-MSUpdates.ps1 -ComputerName 'serverA' -UpdateSource 'MicrosoftUpdate' -Now
This will create a backup checkpoint of exampleserverA and then run updates on it immediately after.

.EXAMPLE
.\Install-MSUpdates.ps1 -ComputerName 'serverB' -UpdateSource 'WindowsUpdate' -At (Get-Date).AddHours(1)
This will run updates on exampleserverB in one hour.

.EXAMPLE
.\Install-MSUpdates.ps1 -ComputerName 'serverC' -Credential (Import-Clixml .\Credential.dat) -Now -Verbose *>&1 | %{$i++;Write-StreamToEventLog -Stream $_ -id $i -logname application -source updatejob}
This is an example of using Install-MSUpdates in conjunction with the EventLogTools module.
This is helpful for running Install-MSUpdates.ps1 in a scheduled task and then outputting the results to an EventLog.
A Credential parameter takes in an encrypted dat file.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string[]]$ComputerName,

    [Parameter(Mandatory=$true,ParameterSetName='Now')]
    [switch]$Now,

    [Parameter(Mandatory=$true,ParameterSetName='At')]
    [ValidateScript({$_ -gt (Get-Date)})]
    [datetime]$At,

    [Parameter(Mandatory=$true)]
    [ValidateSet('MicrosoftUpdate','WindowsUpdate')]
    [string]$UpdateSource,

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential
)

#BEGIN
$ErrorActionPreference='Stop'
$PackageProvider='NuGet'
$RepositorySource='PSGallery'
$UpdateModule='PSWindowsUpdate'

#PROCESS
ForEach ($Computer in $ComputerName) {
    Try {
        #Session
        if (!$Credential) {
            $Session = New-PSSession -ComputerName $Computer
        }
        else {
            Try   {$Session = New-PSSession -ComputerName $Computer -Credential $Credential}
            Catch {$Session = New-PSSession -ComputerName $Computer -UseSSL -Credential $Credential}
        }
        Write-Verbose "PSSession to $Computer created"

        #Install Package Manager
        Invoke-Command -Session $Session -ScriptBlock {Install-PackageProvider -Name $Using:PackageProvider -Force | Out-Null}
        Write-Verbose "Package Provider $PackageProvider installed"

        #Install Update Module
        Invoke-Command -Session $Session -ScriptBlock {Install-Module -Name $Using:UpdateModule -Repository $Using:RepositorySource -Force}
        Write-Verbose "$UpdateModule from $RepositorySource installed"

        #Build Script Parameter for Invoke-WUJob
        $Script = "ipmo $UpdateModule;Install-WindowsUpdate -AcceptAll -AutoReboot -$UpdateSource -UpdateType Software"

        #Build Parameters for Invoke-WUJob
        if ($Now) {
            $ScriptBlock = [ScriptBlock]::Create("Invoke-WUJob -Script '$Script' -RunNow -Confirm:`$false")
        }
        if ($At) {
            $AtDateString = $At.ToString()
            $ScriptBlock = [ScriptBlock]::Create("Invoke-WUJob -Script '$Script' -TriggerDate (Get-Date '$AtDateString') -Confirm:`$false")
        }

        #Send Update Command
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock
        Write-Verbose "Update task has been scheduled on $Computer"
    }
    Catch {
        $PSCmdlet.WriteError($_)
        Continue
    }
    Finally {
        Try {
            if ($Session) {
                Remove-PSSession -Session $Session
                Write-Verbose "PSSession to $Computer closed"
            }
        }
        Catch {
            $PSCmdlet.WriteError($_)
        }
    }
}