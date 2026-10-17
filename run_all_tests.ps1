<#
.SYNOPSIS
    Runs the Wild Wild Cards Godot 4.x test suite with per-test timeout and process isolation.

.DESCRIPTION
    Executes specified Godot tests sequentially. Each test is monitored with a configurable
    timeout (default: 60s). If a test hangs or exceeds the timeout, only the specific Godot
    process launched for that test and its child processes are terminated, leaving unrelated
    Godot editor or application instances unaffected.

.PARAMETER TimeoutSeconds
    Timeout limit in seconds per test. Defaults to 60.

.PARAMETER StopOnFailure
    If set, stops execution on the first test failure or timeout. Defaults to false.

.PARAMETER GodotPath
    Path to the Godot console executable. Defaults to standard project path.

.PARAMETER Headless
    If set, runs Godot in --headless mode. Defaults to false.

.PARAMETER Tests
    List of test scripts to run. If omitted, runs the comprehensive test suite.
#>
param(
    [int]$TimeoutSeconds = 60,
    [switch]$StopOnFailure = $false,
    [string]$GodotPath = "D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$Headless = $false,
    [string[]]$Tests = @()
)

if (-not (Test-Path $GodotPath)) {
    Write-Error "Godot executable not found at: $GodotPath"
    exit 2
}

if ($Tests.Count -eq 0) {
    $Tests = @(
        'test_rules.gd',
        'test_profile.gd',
        'test_profile_resets.gd',
        'test_bot_personality.gd',
        'test_difficulty.gd',
        'test_match_history_data.gd',
        'test_gauntlet_data.gd',
        'test_arenas.gd',
        'test_revolvers.gd',
        'test_finishers_data.gd',
        'test_replays.gd',
        'test_tournament_data.gd',
        'test_tournament.gd',
        'test_tournament_registry.gd',
        'test_multiplayer.gd',
        'test_gauntlet.gd'
    )
}

Write-Host "==========================================================="
Write-Host " Wild Wild Cards Test Runner"
Write-Host " Godot:        $GodotPath"
Write-Host " Mode:         $(if ($Headless) { 'Headless' } else { 'Windowed' })"
Write-Host " Timeout:      ${TimeoutSeconds}s per test"
Write-Host " StopOnFail:   $StopOnFailure"
Write-Host " Total Tests:  $($Tests.Count)"
Write-Host "==========================================================="
Write-Host ""

$totalPassed = 0
$totalFailed = 0
$totalTimedOut = 0
$failedTests = @()

$swOverall = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($testName in $Tests) {
    Write-Host "-----------------------------------------------------------"
    Write-Host ">>> Running: $testName"

    $argList = @("--path", ".")
    if ($Headless) {
        $argList += "--headless"
    }
    $argList += @("--script", "tests/$testName")

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $GodotPath
    $psi.Arguments = $argList -join " "
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $swTest = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)
    $godotPid = $proc.Id

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
    $swTest.Stop()
    $elapsedSec = [math]::Round($swTest.Elapsed.TotalSeconds, 2)

    $isTimedOut = $false
    $stdoutContent = ""
    $stderrContent = ""
    $exitCode = -1

    if (-not $exited) {
        $isTimedOut = $true
        Write-Host "ERROR: $testName timed out after ${TimeoutSeconds}s! Terminating Godot PID $godotPid..." -ForegroundColor Red
        
        # Terminate only child processes of this specific Godot instance
        try {
            $childProcs = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $godotPid }
            foreach ($child in $childProcs) {
                Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignore query errors
        }

        # Terminate this specific Godot process
        try {
            $proc.Kill()
            $proc.WaitForExit(5000) | Out-Null
        } catch {
            # Ignore kill errors
        }

        try {
            $stdoutContent = $stdoutTask.Result
            $stderrContent = $stderrTask.Result
        } catch {
            # Ignore read errors on killed process
        }
    } else {
        $proc.WaitForExit()
        $stdoutContent = $stdoutTask.Result
        $stderrContent = $stderrTask.Result
        $exitCode = $proc.ExitCode
    }

    if ($stdoutContent) {
        $lines = ($stdoutContent -split "`r?`n") | Where-Object { $_ -match "\S" }
        $summaryLines = $lines | Select-Object -Last 4
        foreach ($l in $summaryLines) {
            Write-Host "  $l"
        }
    }

    if ($exitCode -eq 0 -and -not $isTimedOut) {
        Write-Host "PASS: $testName (${elapsedSec}s)" -ForegroundColor Green
        $totalPassed++
    } else {
        if ($isTimedOut) {
            Write-Host "FAIL: $testName (TIMED OUT after ${elapsedSec}s)" -ForegroundColor Red
            $totalTimedOut++
        } else {
            Write-Host "FAIL: $testName (Exit code: $exitCode, ${elapsedSec}s)" -ForegroundColor Red
            $totalFailed++
        }
        $failedTests += $testName

        if ($stderrContent) {
            Write-Host "--- STDERR ---" -ForegroundColor Yellow
            Write-Host $stderrContent -ForegroundColor Yellow
        }
        if ($stdoutContent -and $exitCode -ne 0) {
            Write-Host "--- RECENT STDOUT ---" -ForegroundColor DarkYellow
            $errLines = ($stdoutContent -split "`r?`n") | Select-Object -Last 10
            Write-Host ($errLines -join "`n")
        }

        if ($StopOnFailure) {
            Write-Host "Stopping on first failure as requested." -ForegroundColor Yellow
            break
        }
    }
}

$swOverall.Stop()
$overallSec = [math]::Round($swOverall.Elapsed.TotalSeconds, 2)

Write-Host ""
Write-Host "==========================================================="
Write-Host " TEST RUN SUMMARY"
Write-Host " Overall Time: ${overallSec}s"
Write-Host " Passed:       $totalPassed"
Write-Host " Failed:       $totalFailed"
Write-Host " Timed Out:    $totalTimedOut"
if ($failedTests.Count -gt 0) {
    Write-Host " Failed Tests: $($failedTests -join ', ')" -ForegroundColor Red
} else {
    Write-Host " All tests passed successfully!" -ForegroundColor Green
}
Write-Host "==========================================================="

$totalErrors = $totalFailed + $totalTimedOut
exit $totalErrors
