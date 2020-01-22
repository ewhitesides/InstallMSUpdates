# InstallMSUpdates
Script to issue a windows or microsoft update job to remote machines.

## Usage Example
```powershell
.\Install-MSUpdates.ps1 -ComputerName 'serverA' -UpdateSource 'MicrosoftUpdate' -Now
```
This will schedule a microsoft update job on serverA immediately.

## Usage Example
```powershell
.\Install-MSUpdates.ps1 -ComputerName 'serverB' -UpdateSource 'WindowsUpdate' -At (Get-Date).AddHours(1)
```
This will run windows updates on exampleserverB in one hour.