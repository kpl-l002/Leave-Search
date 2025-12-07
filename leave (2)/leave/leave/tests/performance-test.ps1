# Search Engine Performance Test Script
# Tests for 1000+ QPS (Queries Per Second) capability

param(
    [string]$BaseUrl = "http://localhost:5000",
    [int]$TargetQPS = 1000,
    [int]$TestDurationSeconds = 60,
    [int]$WarmupSeconds = 10,
    [string]$TestQueriesFile = "test-queries.txt",
    [string]$ResultsFile = "performance-results.json"
)

# Test queries in Chinese covering different scenarios
$DefaultTestQueries = @(
    "人工智能",
    "机器学习",
    "深度学习",
    "自然语言处理",
    "计算机视觉",
    "数据科学",
    "云计算",
    "大数据",
    "区块链",
    "物联网",
    "5G技术",
    "量子计算",
    "自动驾驶",
    "智能家居",
    "电子商务",
    "移动支付",
    "社交媒体",
    "在线教育",
    "远程办公",
    "数字营销"
)

# Create test queries file if it doesn't exist
if (-not (Test-Path $TestQueriesFile)) {
    $DefaultTestQueries | Out-File -FilePath $TestQueriesFile -Encoding UTF8
    Write-Host "Created test queries file: $TestQueriesFile" -ForegroundColor Green
}

# Load test queries
$TestQueries = Get-Content $TestQueriesFile -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }
Write-Host "Loaded $($TestQueries.Count) test queries" -ForegroundColor Cyan

# Performance metrics collection
$PerformanceMetrics = @{
    StartTime = Get-Date
    TargetQPS = $TargetQPS
    TestDuration = $TestDurationSeconds
    Requests = @()
    Errors = @()
    Latencies = @()
    QPSHistory = @()
    MemoryUsage = @()
    CPUUsage = @()
}

# HTTP client configuration
$HttpClient = [System.Net.Http.HttpClient]::new()
$HttpClient.Timeout = [TimeSpan]::FromSeconds(10)
$HttpClient.DefaultRequestHeaders.Add("User-Agent", "SearchEngine-Performance-Test/1.0")

# Performance counters
$ProcessorCounter = [System.Diagnostics.PerformanceCounter]::new("Processor", "% Processor Time", "_Total")
$MemoryCounter = [System.Diagnostics.PerformanceCounter]::new("Memory", "Available MBytes")

# Test state
$IsRunning = $true
$RequestCount = 0
$ErrorCount = 0
$SuccessCount = 0
$TotalLatency = 0
$MaxLatency = 0
$MinLatency = [int]::MaxValue

# Results collection
$Results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

# Function to make a single search request
function Invoke-SearchRequest {
    param([string]$Query, [int]$RequestId)
    
    $StartTime = [DateTime]::UtcNow
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $EncodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
        $Url = "$BaseUrl/api/search?query=$EncodedQuery&page=1&pageSize=10"
        
        $Response = $HttpClient.GetAsync($Url).Result
        $Stopwatch.Stop()
        
        $EndTime = [DateTime]::UtcNow
        $Latency = $Stopwatch.ElapsedMilliseconds
        
        $Result = @{
            RequestId = $RequestId
            Query = $Query
            StartTime = $StartTime
            EndTime = $EndTime
            Latency = $Latency
            StatusCode = [int]$Response.StatusCode
            Success = $Response.IsSuccessStatusCode
            ResponseSize = 0
            Error = $null
        }
        
        if ($Response.IsSuccessStatusCode) {
            $Content = $Response.Content.ReadAsStringAsync().Result
            $Result.ResponseSize = $Content.Length
            $SuccessCount++
        } else {
            $ErrorCount++
            $Result.Error = "HTTP $($Response.StatusCode)"
        }
        
        # Update latency statistics
        $TotalLatency += $Latency
        if ($Latency -gt $MaxLatency) { $MaxLatency = $Latency }
        if ($Latency -lt $MinLatency) { $MinLatency = $Latency }
        
        return $Result
        
    } catch [System.Net.Http.HttpRequestException] {
        $Stopwatch.Stop()
        $ErrorCount++
        
        return @{
            RequestId = $RequestId
            Query = $Query
            StartTime = $StartTime
            EndTime = [DateTime]::UtcNow
            Latency = $Stopwatch.ElapsedMilliseconds
            StatusCode = 0
            Success = $false
            ResponseSize = 0
            Error = $_.Exception.Message
        }
    } catch {
        $Stopwatch.Stop()
        $ErrorCount++
        
        return @{
            RequestId = $RequestId
            Query = $Query
            StartTime = $StartTime
            EndTime = [DateTime]::UtcNow
            Latency = $Stopwatch.ElapsedMilliseconds
            StatusCode = 0
            Success = $false
            ResponseSize = 0
            Error = $_.Exception.Message
        }
    }
}

# Function to generate load at target QPS
function Start-LoadGeneration {
    param([int]$QPS)
    
    $Interval = 1000 / $QPS  # milliseconds between requests
    $RequestId = 0
    
    Write-Host "Starting load generation at $QPS QPS (interval: $Interval ms)" -ForegroundColor Yellow
    
    while ($IsRunning) {
        $RequestId++
        $Query = $TestQueries | Get-Random
        
        # Start request in background
        [void][System.Threading.Tasks.Task]::Run({
            param($Query, $RequestId)
            $Result = Invoke-SearchRequest -Query $Query -RequestId $RequestId
            $Results.Add($Result)
        }.GetNewClosure(), @($Query, $RequestId))
        
        # Wait for next request
        Start-Sleep -Milliseconds $Interval
    }
}

# Function to monitor system performance
function Start-PerformanceMonitoring {
    $SampleCount = 0
    
    while ($IsRunning) {
        $SampleCount++
        
        # Get current metrics
        $CurrentTime = [DateTime]::UtcNow
        $ElapsedSeconds = ($CurrentTime - $PerformanceMetrics.StartTime).TotalSeconds
        
        # Calculate current QPS
        $CurrentQPS = if ($ElapsedSeconds -gt 0) { $Results.Count / $ElapsedSeconds } else { 0 }
        
        # Get system metrics
        $CPU = try { $ProcessorCounter.NextValue() } catch { 0 }
        $Memory = try { $MemoryCounter.NextValue() } catch { 0 }
        
        # Record metrics
        $PerformanceMetrics.QPSHistory += @{
            Time = $CurrentTime
            QPS = [Math]::Round($CurrentQPS, 2)
            RequestCount = $Results.Count
            ErrorCount = $ErrorCount
            SuccessRate = if ($Results.Count -gt 0) { [Math]::Round(($SuccessCount / $Results.Count) * 100, 2) } else { 0 }
        }
        
        $PerformanceMetrics.CPUUsage += @{
            Time = $CurrentTime
            CPU = [Math]::Round($CPU, 2)
        }
        
        $PerformanceMetrics.MemoryUsage += @{
            Time = $CurrentTime
            AvailableMemoryMB = [Math]::Round($Memory, 2)
        }
        
        # Display real-time stats
        if ($SampleCount % 5 -eq 0) {
            $AvgLatency = if ($Results.Count -gt 0) { [Math]::Round(($TotalLatency / $Results.Count), 2) } else { 0 }
            
            Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] " -NoNewline -ForegroundColor Gray
            Write-Host "QPS: $([Math]::Round($CurrentQPS, 0))" -NoNewline -ForegroundColor Cyan
            Write-Host " | Requests: $($Results.Count)" -NoNewline -ForegroundColor Green
            Write-Host " | Errors: $ErrorCount" -NoNewline -ForegroundColor Red
            Write-Host " | Success: $([Math]::Round(($SuccessCount / [Math]::Max(1, $Results.Count)) * 100, 1))%" -NoNewline -ForegroundColor Yellow
            Write-Host " | Avg Latency: ${AvgLatency}ms" -NoNewline -ForegroundColor Magenta
            Write-Host " | CPU: $([Math]::Round($CPU, 1))%" -NoNewline -ForegroundColor White
            Write-Host " | Memory: $([Math]::Round($Memory, 0))MB"
        }
        
        Start-Sleep -Seconds 1
    }
}

# Function to run comprehensive performance tests
function Start-PerformanceTest {
    Write-Host "=== Search Engine Performance Test ===" -ForegroundColor Green
    Write-Host "Target QPS: $TargetQPS" -ForegroundColor Cyan
    Write-Host "Test Duration: $TestDurationSeconds seconds" -ForegroundColor Cyan
    Write-Host "Warmup Duration: $WarmupSeconds seconds" -ForegroundColor Cyan
    Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
    Write-Host ""
    
    # Test phases
    $Phases = @(
        @{ Name = "Warmup"; Duration = $WarmupSeconds; QPS = [int]($TargetQPS * 0.5) },
        @{ Name = "Ramp Up"; Duration = 10; QPS = [int]($TargetQPS * 0.75) },
        @{ Name = "Target Load"; Duration = $TestDurationSeconds; QPS = $TargetQPS },
        @{ Name = "Peak Load"; Duration = 10; QPS = [int]($TargetQPS * 1.25) },
        @{ Name = "Cooldown"; Duration = 5; QPS = [int]($TargetQPS * 0.25) }
    )
    
    foreach ($Phase in $Phases) {
        Write-Host "Starting phase: $($Phase.Name)" -ForegroundColor Yellow
        Write-Host "Duration: $($Phase.Duration)s, QPS: $($Phase.QPS)" -ForegroundColor Gray
        
        $PhaseStart = [DateTime]::UtcNow
        $PhaseEnd = $PhaseStart.AddSeconds($Phase.Duration)
        
        # Start load generation for this phase
        $LoadTask = [System.Threading.Tasks.Task]::Run({
            param($QPS)
            Start-LoadGeneration -QPS $QPS
        }, $Phase.QPS)
        
        # Wait for phase duration
        while ([DateTime]::UtcNow -lt $PhaseEnd -and $IsRunning) {
            Start-Sleep -Seconds 1
        }
        
        Write-Host "Completed phase: $($Phase.Name)" -ForegroundColor Green
        Write-Host ""
    }
    
    # Stop load generation
    $IsRunning = $false
    Start-Sleep -Seconds 2  # Allow pending requests to complete
}

# Function to analyze results and generate report
function Get-PerformanceReport {
    Write-Host "=== Performance Test Analysis ===" -ForegroundColor Green
    
    $TotalRequests = $Results.Count
    $TestDuration = ($PerformanceMetrics.StartTime - [DateTime]::UtcNow).TotalSeconds
    $ActualQPS = if ($TestDuration -gt 0) { $TotalRequests / $TestDuration } else { 0 }
    
    $ErrorRate = if ($TotalRequests -gt 0) { ($ErrorCount / $TotalRequests) * 100 } else { 0 }
    $SuccessRate = if ($TotalRequests -gt 0) { ($SuccessCount / $TotalRequests) * 100 } else { 0 }
    
    $AvgLatency = if ($TotalRequests -gt 0) { $TotalLatency / $TotalRequests } else { 0 }
    $P50Latency = Get-PercentileLatency -Percentile 50
    $P95Latency = Get-PercentileLatency -Percentile 95
    $P99Latency = Get-PercentileLatency -Percentile 99
    
    # Response time distribution
    $LatencyDistribution = Get-LatencyDistribution
    
    # Performance grade
    $PerformanceGrade = Get-PerformanceGrade -QPS $ActualQPS -TargetQPS $TargetQPS -ErrorRate $ErrorRate -P95Latency $P95Latency
    
    Write-Host "Total Requests: $TotalRequests" -ForegroundColor Cyan
    Write-Host "Target QPS: $TargetQPS" -ForegroundColor Cyan
    Write-Host "Actual QPS: $([Math]::Round($ActualQPS, 2))" -ForegroundColor $(if ($ActualQPS -ge $TargetQPS) { "Green" } else { "Red" })
    Write-Host "Success Rate: $([Math]::Round($SuccessRate, 2))%" -ForegroundColor $(if ($SuccessRate -ge 95) { "Green" } elseif ($SuccessRate -ge 90) { "Yellow" } else { "Red" })
    Write-Host "Error Rate: $([Math]::Round($ErrorRate, 2))%" -ForegroundColor $(if ($ErrorRate -le 5) { "Green" } elseif ($ErrorRate -le 10) { "Yellow" } else { "Red" })
    Write-Host ""
    Write-Host "Response Time Analysis:" -ForegroundColor Yellow
    Write-Host "Average: $([Math]::Round($AvgLatency, 2))ms" -ForegroundColor White
    Write-Host "P50 (Median): $([Math]::Round($P50Latency, 2))ms" -ForegroundColor White
    Write-Host "P95: $([Math]::Round($P95Latency, 2))ms" -ForegroundColor $(if ($P95Latency -le 200) { "Green" } elseif ($P95Latency -le 500) { "Yellow" } else { "Red" })
    Write-Host "P99: $([Math]::Round($P99Latency, 2))ms" -ForegroundColor White
    Write-Host "Min: $MinLatency ms" -ForegroundColor Green
    Write-Host "Max: $MaxLatency ms" -ForegroundColor Red
    Write-Host ""
    Write-Host "Performance Grade: $PerformanceGrade" -ForegroundColor $(switch ($PerformanceGrade[0]) {
        "A" { "Green" }
        "B" { "Yellow" }
        "C" { "Red" }
        default { "Red" }
    })
    
    # Generate detailed report
    $Report = @{
        Summary = @{
            TotalRequests = $TotalRequests
            TargetQPS = $TargetQPS
            ActualQPS = [Math]::Round($ActualQPS, 2)
            SuccessRate = [Math]::Round($SuccessRate, 2)
            ErrorRate = [Math]::Round($ErrorRate, 2)
            PerformanceGrade = $PerformanceGrade
            TestDuration = [Math]::Round($TestDuration, 2)
        }
        ResponseTimes = @{
            Average = [Math]::Round($AvgLatency, 2)
            P50 = [Math]::Round($P50Latency, 2)
            P95 = [Math]::Round($P95Latency, 2)
            P99 = [Math]::Round($P99Latency, 2)
            Min = $MinLatency
            Max = $MaxLatency
            Distribution = $LatencyDistribution
        }
        QPSHistory = $PerformanceMetrics.QPSHistory
        SystemMetrics = @{
            CPUUsage = $PerformanceMetrics.CPUUsage
            MemoryUsage = $PerformanceMetrics.MemoryUsage
        }
        RawResults = $Results.ToArray()
    }
    
    return $Report
}

# Helper function to calculate percentile latency
function Get-PercentileLatency {
    param([int]$Percentile)
    
    $Latencies = $Results | Where-Object { $_.Success } | ForEach-Object { $_.Latency } | Sort-Object
    if ($Latencies.Count -eq 0) { return 0 }
    
    $Index = [int][Math]::Ceiling($Latencies.Count * ($Percentile / 100.0)) - 1
    if ($Index -lt 0) { $Index = 0 }
    if ($Index -ge $Latencies.Count) { $Index = $Latencies.Count - 1 }
    
    return $Latencies[$Index]
}

# Helper function to get latency distribution
function Get-LatencyDistribution {
    $Latencies = $Results | Where-Object { $_.Success } | ForEach-Object { $_.Latency }
    if ($Latencies.Count -eq 0) { return @{} }
    
    $Ranges = @{
        "0-50ms" = ($Latencies | Where-Object { $_ -le 50 }).Count
        "51-100ms" = ($Latencies | Where-Object { $_ -gt 50 -and $_ -le 100 }).Count
        "101-200ms" = ($Latencies | Where-Object { $_ -gt 100 -and $_ -le 200 }).Count
        "201-500ms" = ($Latencies | Where-Object { $_ -gt 200 -and $_ -le 500 }).Count
        "501-1000ms" = ($Latencies | Where-Object { $_ -gt 500 -and $_ -le 1000 }).Count
        ">1000ms" = ($Latencies | Where-Object { $_ -gt 1000 }).Count
    }
    
    return $Ranges
}

# Helper function to calculate performance grade
function Get-PerformanceGrade {
    param(
        [double]$QPS,
        [int]$TargetQPS,
        [double]$ErrorRate,
        [double]$P95Latency
    )
    
    $QPSRatio = $QPS / $TargetQPS
    
    if ($QPSRatio -ge 1.0 -and $ErrorRate -le 1 -and $P95Latency -le 200) {
        return "A+ (Excellent)"
    } elseif ($QPSRatio -ge 0.9 -and $ErrorRate -le 2 -and $P95Latency -le 300) {
        return "A (Very Good)"
    } elseif ($QPSRatio -ge 0.8 -and $ErrorRate -le 5 -and $P95Latency -le 500) {
        return "B+ (Good)"
    } elseif ($QPSRatio -ge 0.7 -and $ErrorRate -le 10 -and $P95Latency -le 1000) {
        return "B (Acceptable)"
    } else {
        return "C (Needs Improvement)"
    }
}

# Main execution
function Main {
    try {
        # Start performance monitoring
        $MonitoringTask = [System.Threading.Tasks.Task]::Run({
            Start-PerformanceMonitoring
        })
        
        # Run performance test
        Start-PerformanceTest
        
        # Generate and save report
        $Report = Get-PerformanceReport
        
        # Save results to file
        $Report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ResultsFile -Encoding UTF8
        Write-Host ""
        Write-Host "Performance test results saved to: $ResultsFile" -ForegroundColor Green
        
        # Display recommendations
        Write-Host ""
        Write-Host "=== Performance Recommendations ===" -ForegroundColor Yellow
        
        if ($Report.Summary.ActualQPS -lt $TargetQPS) {
            Write-Host "⚠️  QPS target not met. Consider:" -ForegroundColor Red
            Write-Host "   - Scaling out with more server instances" -ForegroundColor White
            Write-Host "   - Optimizing Elasticsearch queries" -ForegroundColor White
            Write-Host "   - Increasing caching layer efficiency" -ForegroundColor White
            Write-Host "   - Upgrading hardware resources" -ForegroundColor White
        }
        
        if ($Report.ResponseTimes.P95 -gt 200) {
            Write-Host "⚠️  Response time exceeds 200ms target. Consider:" -ForegroundColor Red
            Write-Host "   - Optimizing Chinese tokenization performance" -ForegroundColor White
            Write-Host "   - Reducing Elasticsearch query complexity" -ForegroundColor White
            Write-Host "   - Implementing query result caching" -ForegroundColor White
            Write-Host "   - Using faster hardware (SSD, more RAM)" -ForegroundColor White
        }
        
        if ($Report.Summary.ErrorRate -gt 5) {
            Write-Host "⚠️  Error rate exceeds 5% target. Check:" -ForegroundColor Red
            Write-Host "   - Elasticsearch cluster health" -ForegroundColor White
            Write-Host "   - Network connectivity and timeouts" -ForegroundColor White
            Write-Host "   - Server resource utilization" -ForegroundColor White
            Write-Host "   - Application logs for exceptions" -ForegroundColor White
        }
        
        if ($Report.Summary.ActualQPS -ge $TargetQPS -and $Report.ResponseTimes.P95 -le 200 -and $Report.Summary.ErrorRate -le 5) {
            Write-Host "✅ Performance targets met! System can handle $TargetQPS+ QPS with sub-200ms response times." -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Error during performance test: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    } finally {
        # Cleanup
        $HttpClient?.Dispose()
        $ProcessorCounter?.Dispose()
        $MemoryCounter?.Dispose()
    }
}

# Run the performance test
Main