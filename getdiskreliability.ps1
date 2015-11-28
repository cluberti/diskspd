$ErrorActionPreference = "SilentlyContinue"

Write-Host "  Checking Disk Health" -ForegroundColor Cyan
Write-Host ""
Write-Host "    https://technet.microsoft.com/en-us/library/jj218346(v=wps.620).aspx"
Write-Host ""

Get-PhysicalDisk | Get-StorageReliabilityCounter | Sort-Object -property DeviceId

