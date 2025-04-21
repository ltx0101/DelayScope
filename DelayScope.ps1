param (
    [int]$Iterations = 10,
    [switch]$IncludeNetworkTest,
    [switch]$IncludeUITest,
    [switch]$DetailedOutput
)

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.BackgroundColor = 'Black'
Clear-Host

cls
Write-Host "Please close everything, test will start in 5 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 1

Write-Host "Test is starting in:" -ForegroundColor Green
Start-Sleep -Seconds 1

for ($i = 5; $i -gt 0; $i--) {
    Write-Host "$i" -ForegroundColor Red
    Start-Sleep -Seconds 1
}
cls
Write-Host "Test is starting now!" -ForegroundColor Cyan
Start-Sleep -Seconds 1
cls

$results = @()

function Write-ProgressHelper {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$SecondsRemaining
    )
    
    if ($DetailedOutput) {
        Write-Host "[$([datetime]::Now.ToString('HH:mm:ss'))] $Status" -ForegroundColor Cyan
    }
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -SecondsRemaining $SecondsRemaining
}

function Measure-CpuResponsiveness {
    param([int]$Iterations = 10)
    
    $cpuResults = @()
    $totalTime = 0
    
    Write-ProgressHelper -Activity "CPU Test" -Status "Measuring CPU performance..." -PercentComplete 10 -SecondsRemaining ($Iterations * 2)
    
    for ($i = 1; $i -le $Iterations; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = 1..1000000 | ForEach-Object { [math]::Sqrt($_) }
        $sw.Stop()
        
        $time = $sw.Elapsed.TotalMilliseconds
        $cpuResults += $time
        $totalTime += $time
        
        Write-ProgressHelper -Activity "CPU Test" -Status "Completed iteration $i/$Iterations ($([math]::Round($time,2)) ms)" -PercentComplete (($i / $Iterations) * 100) -SecondsRemaining ($Iterations - $i)
    }
    
    $avgTime = $totalTime / $Iterations
    $cpuScore = 10000 / $avgTime
    
    return @{
        AverageTime = [math]::Round($avgTime, 2)
        MinTime = [math]::Round(($cpuResults | Measure -Minimum).Minimum, 2)
        MaxTime = [math]::Round(($cpuResults | Measure -Maximum).Maximum, 2)
        CPUScore = [math]::Round($cpuScore, 2)
        RawData = $cpuResults
    }
}


function Measure-DiskResponsiveness {
    param([int]$Iterations = 5)
    
    $diskResults = @()
    $totalTime = 0
    $testFile = "$env:TEMP\disk_test.tmp"
    
    try {
        Write-ProgressHelper -Activity "Disk Test" -Status "Measuring disk performance..." -PercentComplete 10 -SecondsRemaining ($Iterations * 3)

        $testData = [byte[]]::new(1MB)
        (new-object Random).NextBytes($testData)
        
        for ($i = 1; $i -le $Iterations; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            [System.IO.File]::WriteAllBytes($testFile, $testData)
            $sw.Stop()
            $writeTime = $sw.Elapsed.TotalMilliseconds
            
            $sw.Restart()
            $readData = [System.IO.File]::ReadAllBytes($testFile)
            $sw.Stop()
            $readTime = $sw.Elapsed.TotalMilliseconds
            
            $totalTime += ($writeTime + $readTime)
            $diskResults += @{
                WriteTime = $writeTime
                ReadTime = $readTime
                TotalTime = $writeTime + $readTime
            }
            
            Write-ProgressHelper -Activity "Disk Test" -Status "Completed iteration $i/$Iterations (W: $([math]::Round($writeTime,2)) ms, R: $([math]::Round($readTime,2)) ms)" -PercentComplete (($i / $Iterations) * 100) -SecondsRemaining ($Iterations - $i)
        }
        
        Remove-Item $testFile -ErrorAction SilentlyContinue
        
        $avgTime = $totalTime / ($Iterations * 2)
        $diskScore = 1000 / $avgTime
        
        return @{
            AverageTime = [math]::Round($avgTime, 2)
            MinTime = [math]::Round(($diskResults.TotalTime | Measure -Minimum).Minimum, 2)
            MaxTime = [math]::Round(($diskResults.TotalTime | Measure -Maximum).Maximum, 2)
            DiskScore = [math]::Round($diskScore, 2)
            RawData = $diskResults
        }
    }
    catch {
        Write-Warning "Disk test failed: $_"
        return $null
    }
}

function Measure-MemoryResponsiveness {
    param([int]$Iterations = 5)
    
    $memResults = @()
    $totalTime = 0
    
    Write-ProgressHelper -Activity "Memory Test" -Status "Measuring memory performance..." -PercentComplete 10 -SecondsRemaining ($Iterations * 1)
    
    for ($i = 1; $i -le $Iterations; $i++) {
        $arraySize = 1MB
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $testArray = [byte[]]::new($arraySize)
        (new-object Random).NextBytes($testArray)

        $sum = 0
        foreach ($byte in $testArray) {
            $sum += $byte
        }
        
        $sw.Stop()
        $time = $sw.Elapsed.TotalMilliseconds
        $memResults += $time
        $totalTime += $time
        
        Write-ProgressHelper -Activity "Memory Test" -Status "Completed iteration $i/$Iterations ($([math]::Round($time,2)) ms)" -PercentComplete (($i / $Iterations) * 100) -SecondsRemaining ($Iterations - $i)
    }
    
    $avgTime = $totalTime / $Iterations
    $memScore = 10000 / $avgTime
    
    return @{
        AverageTime = [math]::Round($avgTime, 2)
        MinTime = [math]::Round(($memResults | Measure -Minimum).Minimum, 2)
        MaxTime = [math]::Round(($memResults | Measure -Maximum).Maximum, 2)
        MemoryScore = [math]::Round($memScore, 2)
        RawData = $memResults
    }
}

function Measure-NetworkResponsiveness {
    param(
        [int]$Iterations = 10,
        [string]$TestHost = "8.8.8.8"
    )
    
    # Validate parameters
    if ($Iterations -le 0) {
        throw "Iterations must be greater than 0"
    }
    
    $netResults = @()
    $successCount = 0
    $totalTime = 0
    
    for ($i = 1; $i -le $Iterations; $i++) {
        try {
            Write-Progress -Activity "Network Test" -Status "Measuring network latency..." `
                -PercentComplete (($i / $Iterations) * 100) `
                -CurrentOperation "Iteration $i/$Iterations"
            
            $ping = Test-Connection -ComputerName $TestHost -Count 1 -ErrorAction Stop
            $time = $ping.ResponseTime
            $netResults += $time
            $totalTime += $time
            $successCount++
        }
        catch {
            Write-Warning "Network test failed for iteration"
            $netResults += $null
        }
    }
    
    
    if ($successCount -gt 0) {
        $avgTime = $totalTime / $successCount
        $netScore = [math]::Min(100, (100 / ($avgTime + 1))) # Prevent division by zero and cap at 100
        
        return @{
            AverageTime = [math]::Round($avgTime, 2)
            MinTime = [math]::Round(($netResults | Where-Object {$_} | Measure -Minimum).Minimum, 2)
            MaxTime = [math]::Round(($netResults | Where-Object {$_} | Measure -Maximum).Maximum, 2)
            PacketLoss = [math]::Round(($Iterations - $successCount) / $Iterations * 100, 2)
            NetworkScore = [math]::Round($netScore, 2)
            RawData = $netResults
            SuccessCount = $successCount
            TotalIterations = $Iterations
        }
    }
    else {
        Write-Warning "All network tests failed"
        return $null
    }
}

try {
    Write-Host "=== System Responsiveness Measurement ===" -ForegroundColor Green
    Write-Host "Starting tests with $Iterations iterations per measurement"

    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $ram = Get-CimInstance Win32_ComputerSystem
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"

    $cpuTest = Measure-CpuResponsiveness -Iterations $Iterations
    $diskTest = Measure-DiskResponsiveness -Iterations $Iterations
    $memTest = Measure-MemoryResponsiveness -Iterations $Iterations
    
    if ($IncludeNetworkTest) {
        $netTest = Measure-NetworkResponsiveness -Iterations $Iterations
    }
    
    $totalScore = 0
    $weightSum = 0
    
    $totalScore += $cpuTest.CPUScore * 0.4
    $weightSum += 0.4
    
    $totalScore += $diskTest.DiskScore * 0.3
    $weightSum += 0.3
    
    $totalScore += $memTest.MemoryScore * 0.2
    $weightSum += 0.2
    
    if ($netTest) {
        $totalScore += $netTest.NetworkScore * 0.1
        $weightSum += 0.1
    }
    
    $overallScore = $totalScore / $weightSum
    cls
    Write-Host "=== Test Results ===" -ForegroundColor Yellow
    Write-Host "System Information:"
    Write-Host "  OS: $($os.Caption) (Build $($os.BuildNumber))"
    Write-Host "  CPU: $($cpu.Name) ($($cpu.NumberOfCores) cores)"
    Write-Host "  RAM: $([math]::Round($ram.TotalPhysicalMemory / 1GB, 2)) GB"
    Write-Host "  System Drive: $($disk.DeviceID) ($([math]::Round($disk.FreeSpace / 1GB, 2)) GB free of $([math]::Round($disk.Size / 1GB, 2)) GB)"
    
    Write-Host "CPU Responsiveness:" -ForegroundColor Cyan
    Write-Host "  Average: $($cpuTest.AverageTime) ms (Score: $($cpuTest.CPUScore))"
    Write-Host "  Range: $($cpuTest.MinTime) - $($cpuTest.MaxTime) ms"
    
    Write-Host "Disk Responsiveness:" -ForegroundColor Cyan
    Write-Host "  Average: $($diskTest.AverageTime) ms (Score: $($diskTest.DiskScore))"
    Write-Host "  Range: $($diskTest.MinTime) - $($diskTest.MaxTime) ms"
    
    Write-Host "Memory Responsiveness:" -ForegroundColor Cyan
    Write-Host "  Average: $($memTest.AverageTime) ms (Score: $($memTest.MemoryScore))"
    Write-Host "  Range: $($memTest.MinTime) - $($memTest.MaxTime) ms"
    
$netTest = Measure-NetworkResponsiveness -Iterations 10

if ($netTest) {
    Write-Host "Network Responsiveness:" -ForegroundColor Cyan
    Write-Host "  Average: $($netTest.AverageTime) ms (Score: $($netTest.NetworkScore))"
    Write-Host "  Range: $($netTest.MinTime) - $($netTest.MaxTime) ms"
    Write-Host "  Packet Loss: $($netTest.PacketLoss)%"
} else {
    Write-Host "Network test failed - could not complete any successful pings" -ForegroundColor Red
}
    
    Write-Host "=== Overall System Responsiveness Score ===" -ForegroundColor Green
    Write-Host "  Score: $([math]::Round($overallScore, 2)) (Higher is better)"

    Write-Host "=== Interpretation ===" -ForegroundColor Yellow
    if ($overallScore -gt 80) {
        Write-Host "  Excellent system responsiveness" -ForegroundColor Green
    }
    elseif ($overallScore -gt 60) {
        Write-Host "  Good system responsiveness" -ForegroundColor DarkGreen
    }
    elseif ($overallScore -gt 40) {
        Write-Host "  Average system responsiveness" -ForegroundColor Yellow
    }
    elseif ($overallScore -gt 20) {
        Write-Host "  Below average system responsiveness" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "  Poor system responsiveness - consider investigating bottlenecks" -ForegroundColor Red
    }

    $resultObj = [PSCustomObject]@{
        Timestamp = Get-Date
        OverallScore = [math]::Round($overallScore, 2)
    }
    
    return $resultObj
}
catch {
    Write-Error "An error occurred during testing: $_"
    exit 1
}
finally {
    Write-Progress -Activity "Complete" -Completed
    pause
}
