$ErrorActionPreference = "SilentlyContinue"


$FileSizeInGB = "100" #Must be 1 or higher
$TimeInSeconds = "10"  #Must be 1 or higher
$WritePercentage = "0"  #Setting to 0 causes 100% read test
$ThreadsPerFile = "1"  #Must be 1 or higher
$FileName = "O:\testfile.dat"  #Filename and path to use as test
$RandomIO = "False"  #True/False
$CachingDisabled = "None"  #All/Windows/None


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

Write-Host "  This script performs a disk performance test using diskspd.exe." -ForegroundColor Cyan
Write-Host "    This script assumes diskspd.exe is located in C:\Windows" -ForegroundColor Yellow
Write-Host "    Edit this script at line 93 if the binary is located elsewhere." -ForegroundColor Yellow
Write-Host ""
Write-Host "    https://gallery.technet.microsoft.com/DiskSpd-a-robust-storage-6cd2f223"
Write-Host ""


Write-Host "##########################" -ForegroundColor Magenta
Write-Host "Legend:" -ForegroundColor Cyan
Write-Host " - QD  = Queue Depth" -ForegroundColor Gray
Write-Host " - IO  = IO Operations/Sec" -ForegroundColor Gray
Write-Host " - MB  = MB/sec throughput" -ForegroundColor Gray
Write-Host " - L   = Latency (ms)" -ForegroundColor Gray
Write-Host " - CPU = Avg CPU%" -ForegroundColor Gray
Write-Host "##########################" -ForegroundColor Magenta
Write-Host ""
Write-Host ""
Write-Host ""


Function Run-Test {
    param ($FileSizeInGB, $TimeInSeconds, $WritePercentage, $ThreadsPerFile, $FileName, $BlockSize, $RandomIO, $CachingDisabled)
    

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
        $x = ""
    }
    
    If ($RandomIO -eq "True")
    {
        $r = "-r"
    }
    ElseIf ($RandomIO -eq "False")
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
    

    ForEach ($i in 1..1) {
        If ($BlockSize -eq "4K" -or $BlockSize -eq "8K")
        {
            Write-Host "######" -ForegroundColor Yellow
            Write-Host "  $BlockSize" -ForegroundColor Yellow
            Write-Host "######" -ForegroundColor Yellow
            Write-Host "QD     IO       MB      L     CPU" -ForegroundColor Gray
            Write-Host "-------------------------------------" -ForegroundColor Gray
        }
        Else
        {
            Write-Host "#######" -ForegroundColor Yellow
            Write-Host "  $BlockSize" -ForegroundColor Yellow
            Write-Host "#######" -ForegroundColor Yellow
            Write-Host "QD     IO       MB      L     CPU" -ForegroundColor Gray
            Write-Host "-------------------------------------" -ForegroundColor Gray
        }
        

        $QueueDepth   = "-o$i"
        $result = Invoke-Expression -Command "C:\Windows\diskspd.exe $c $d $r $w $t $QueueDepth $b $x $L"

     
        foreach ($line in $result)
        {
            if ($line -like "total:*")
            {
                $total=$line; break
            }
        }
        foreach ($line in $result)
        {
            if ($line -like "avg.*")
            {
                $avg=$line; break
            }
        }
        $mbps = $total.Split("|")[2].Trim()
        $iops = $total.Split("|")[3].Trim()
        $latency = $total.Split("|")[4].Trim()
        $cpu = $avg.Split("|")[1].Trim()
        "$i  $iops  $mbps  $latency  $cpu"
        Write-Host ""
    }
}



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

If ($RandomIO -eq "True")
{
    $r = "-r"
    Write-Host " - random I/O" -ForegroundColor Gray
}
ElseIf ($RandomIO -eq "False")
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
Write-Host "##########################" -ForegroundColor Green
Write-Host ""


# Run-Test params:
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName "4K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName "8K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName "16K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName "32K" $RandomIO $CachingDisabled
Run-Test $FileSizeInGB $TimeInSeconds $WritePercentage $ThreadsPerFile $FileName "64K" $RandomIO $CachingDisabled
