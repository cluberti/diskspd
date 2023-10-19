# Parse Params:
[CmdletBinding()]
Param(
    [Parameter(
        Position=0,
        Mandatory=$False,
        HelpMessage="The file to use or create - this will test the drive with the file's drive letter; if no value passed, C:\testfile.dat is used"
        )]
        $FileName = "C:\testfile.dat",
    [Parameter(
        Position=1,
        Mandatory=$False,
        HelpMessage="File size in GB to use - must be 1 or higher; if no value passed, 100 is used"
        )]
        $FileSizeInGB = "100",
    [Parameter(
        Position=2,
        Mandatory=$False,
        HelpMessage="Queue depth up to which to stress controller - will start at 1 and go up to the specified number (1, 4, 8, 16, 32, 64, 128); if no value passed, 32 is used"
        )]
        [ValidateSet('1', '4', '8', '16', '32', '64', '128')]
        $QueueDepth = "32",
    [Parameter(
        Position=3,
        Mandatory=$False,
        HelpMessage="Duration in seconds; if not specified, 10 is used"
        )]
        $TimeInSeconds = "10",
    [Parameter(
        Position=4,
        Mandatory=$False,
        HelpMessage="Write percentage, 0-100; if not specified, 0 is used (100% read test)"
        )]
        $WritePercentage = "0",
    [Parameter(
        Position=5,
        Mandatory=$False,
        HelpMessage="Number of CPU threads to use per file - must be 1 or higher; if not specified, 1 is used"
        )]
        $ThreadsPerFile = "1",
    [Parameter(
        Position=6,
        Mandatory=$False,
        HelpMessage="Test Random I/O vs sequention, True/False; if not specified, False is used (run sequential I/O test)"
        )]
        $RandomIO = $False,
    [Parameter(
        Position=7,
        Mandatory=$False,
        HelpMessage="Caching type disabled, valid values are All, Windows, or None; if not specified, 'None' is used (all caching enabled)"
        )]
        [ValidateSet('None', 'Windows', 'All')]
        $CachingDisabled = "None",
    [Parameter(
        Position=8,
        Mandatory=$False,
        HelpMessage="DiskSpd.exe location; if not specified, it is assumed to be in C:\Windows"
        )]
        $DiskSpd = "C:\Windows\diskspd.exe"
    )


Function Run-Test
{
    Param ($FileSizeInGB, $TimeInSeconds, $WritePercentage, $ThreadsPerFile, $FileName, $QueueDepth, $BlockSize, $RandomIO, $CachingDisabled)
    # diskspd.exe parameters:

    # -c size of testfile.dat
    # -d duration of test in seconds
    # -r random I/O (SQL OLTP)
    # -w percentage writes
    # -t number of threads per file
    # -o number of queued I/Os (test queue depth performance)
    # -b size of writes (8K for SQL load test)
    # -h bypass write cache in software AND hardware
    # -L measure latency in ms

    $c = "-c" + $FileSizeInGB + "G"
    $d = "-d" + $TimeInSeconds
    $w = "-w" + $WritePercentage
    $t = "-t" + $ThreadsPerFile
    $b = "-b" + $BlockSize
    $L = "-L " + $FileName
    If ($CachingDisabled -eq "All")
    {
        $x = "-h"
    }
    ElseIf ($CachingDisabled -eq "Windows")
    {
        $x = "-S"
    }
    ElseIf ($CachingDisabled -eq "None")
    {
        $x = $null
    }

    If ($RandomIO -eq $True)
    {
        $r = "-r"
    }
    ElseIf ($RandomIO -eq $False)
    {
        If ($ThreadsPerFile -eq "1")
        {
            $r = "-s"
        }
        Else
        {
            $r = "-si"
        }
    }

    If ($BlockSize -eq "4K")
    {
        Write-Host ""
        Write-Host ""
        Write-Host "Starting test..." -ForegroundColor Cyan
        Write-Host ""
        Write-Host ""
        Write-Host "######" -ForegroundColor Yellow
        Write-Host "  $BlockSize" -ForegroundColor Yellow
        Write-Host "######" -ForegroundColor Yellow
    }
    ElseIf ($BlockSize -eq "8K")
    {
        Write-Host "######" -ForegroundColor Yellow
        Write-Host "  $BlockSize" -ForegroundColor Yellow
        Write-Host "######" -ForegroundColor Yellow
    }
    Else
    {
        Write-Host "#######" -ForegroundColor Yellow
        Write-Host "  $BlockSize" -ForegroundColor Yellow
        Write-Host "#######" -ForegroundColor Yellow
    }

    $DiskSpdOutput = @()
    ForEach ($i in 1..$QueueDepth)
    {
        If ((($i -eq "1") -or ($i -eq "4") -or ($i -eq "8") -or ($i -eq "16") -or ($i -eq "32") -or ($i -eq "64") -or ($i -eq "128")) -and ($i -le $QueueDepth))
        {
            $o = "-o$i"
            If ($x -eq $null)
            {
                $Result = Invoke-Expression -Command "$DiskSpd $c $d $r $w $t $o $b $L"
            }
            Else
            {
                $Result = Invoke-Expression -Command "$DiskSpd $c $d $r $w $t $o $b $x $L"
            }
            
            ForEach ($line in $result)
            {
                If ($line -like "total:*")
                {
                    $total=$line; break
                }
            }
            Foreach ($line in $result)
            {
                If ($line -like "avg.*")
                {
                    $avg=$line; break
                }
            }

            $Object = [PSCustomObject]@{
                QD        = $i
                IO        = $total.Split("|")[3].Trim()
                MB        = $total.Split("|")[2].Trim()
                L         = $total.Split("|")[4].Trim()
                CPU       = $avg.Split("|")[1].Trim()
            }
            $DiskSpdOutput += $Object
        }
        Else
        {
            # Do nothing, not a valid test queue depth - keep looping until 1, 4, 8, 16, 32, 64, or 12, up until this hits $QueueDepth
        }
    }
    $DiskSpdOutput | Format-Table -AutoSize
}



Clear-Host
Write-Host "  This script performs a disk performance test using diskspd.exe." -ForegroundColor Cyan
Write-Host "    This script is using $Diskspd for this test" -ForegroundColor Yellow
Write-Host ""
Write-Host "    https://gallery.technet.microsoft.com/DiskSpd-a-robust-storage-6cd2f223"
Write-Host ""
Write-Host "##########################" -ForegroundColor Green
Write-Host "This test pass:" -ForegroundColor Cyan

If ($CachingDisabled -eq "All")
{
    $x = "-h"
    Write-Host " - ALL caching disabled" -ForegroundColor Gray
}
ElseIf ($CachingDisabled -eq "Windows")
{
    $x = "-S"
    Write-Host " - Windows caching disabled" -ForegroundColor Gray
}
ElseIf ($CachingDisabled -eq "None")
{
    $x = ""
    Write-Host " - All caching enabled" -ForegroundColor Gray
}

Write-Host " - $FileSizeInGB GB file" -ForegroundColor Gray
Write-Host "   ($FileName)"

If ($RandomIO -eq $True)
{
    $r = "-r"
    Write-Host " - random I/O" -ForegroundColor Gray
}
ElseIf ($RandomIO -eq $False)
{
    $r = "-si"
    Write-Host " - Sequential I/O" -ForegroundColor Gray
}

Write-Host " - $TimeInSeconds second test" -ForegroundColor Gray
If ($ThreadsPerFile -lt "2")
{
    Write-Host " - $ThreadsPerFile thread" -ForegroundColor Gray
}
Else
{
    Write-Host " - $ThreadsPerFile threads" -ForegroundColor Gray
}

If ($WritePercentage -eq "0")
{
    Write-Host " - 100% reads" -ForegroundColor Gray
}
Else
{
    Write-Host " - $WritePercentage% Write" -ForegroundColor Gray
}

Write-Host " - Queue depth $QueueDepth" -ForegroundColor Gray
Write-Host "##########################" -ForegroundColor Green
Write-Host ""
Write-Host ""
Write-Host "##########################" -ForegroundColor Magenta
Write-Host "Legend:" -ForegroundColor Cyan
Write-Host " - QD  = Queue Depth" -ForegroundColor Gray
Write-Host " - IO  = IO Operations/Sec" -ForegroundColor Gray
Write-Host " - MB  = MB/sec throughput" -ForegroundColor Gray
Write-Host " - L   = Latency (ms)" -ForegroundColor Gray
Write-Host " - CPU = Avg CPU%" -ForegroundColor Gray
Write-Host "##########################" -ForegroundColor Magenta

# Run-Test params:
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName $QueueDepth "4K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName $QueueDepth "8K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName $QueueDepth "16K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName $QueueDepth "32K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName $QueueDepth "64K" $RandomIO $CachingDisabled

# Delete temporary file
Start-Sleep 5
Write-Host ""
Write-Host ""
Write-Host "Deleting temporary file $FileName to cleanup..." -ForegroundColor Cyan
Remove-Item -Path $FileName -Force
