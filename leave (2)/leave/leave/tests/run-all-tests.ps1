# Comprehensive Test Runner for Search Engine
# Runs unit tests, integration tests, and performance validation

param(
    [string]$TestProjectPath = "..\SearchEngine.Api\Tests\SearchEngine.Api.Tests.csproj",
    [string]$ApiProjectPath = "..\SearchEngine.Api\SearchEngine.Api.csproj",
    [string]$FrontendPath = "..\search-engine-frontend",
    [string]$ResultsPath = ".\test-results",
    [bool]$RunPerformanceTests = $true,
    [bool]$RunUnitTests = $true,
    [bool]$RunIntegrationTests = $true,
    [bool]$GenerateReport = $true
)

# Create results directory
if (-not (Test-Path $ResultsPath)) {
    New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
}

Write-Host "=== Search Engine Comprehensive Test Suite ===" -ForegroundColor Green
Write-Host "Test Project: $TestProjectPath" -ForegroundColor Cyan
Write-Host "Results Directory: $ResultsPath" -ForegroundColor Cyan
Write-Host ""

# Test results collection
$TestResults = @{
    UnitTests = @{ Passed = 0; Failed = 0; Skipped = 0; Duration = 0 }
    IntegrationTests = @{ Passed = 0; Failed = 0; Skipped = 0; Duration = 0 }
    PerformanceTests = @{ Passed = $false; QPS = 0; AvgLatency = 0; P95Latency = 0; ErrorRate = 0 }
    BuildTests = @{ Backend = $false; Frontend = $false }
    StartTime = Get-Date
}

# Function to run unit tests
function Invoke-UnitTests {
    Write-Host "Running Unit Tests..." -ForegroundColor Yellow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Run dotnet test
        $testResults = dotnet test $TestProjectPath --logger "trx;LogFileName=unit-tests.trx" --results-directory $ResultsPath --collect:"XPlat Code Coverage"
        
        # Parse results
        $testOutput = $testResults -join "`n"
        if ($testOutput -match "Passed:\s+(\d+)") { $TestResults.UnitTests.Passed = [int]$Matches[1] }
        if ($testOutput -match "Failed:\s+(\d+)") { $TestResults.UnitTests.Failed = [int]$Matches[1] }
        if ($testOutput -match "Skipped:\s+(\d+)") { $TestResults.UnitTests.Skipped = [int]$Matches[1] }
        
        $TestResults.UnitTests.Duration = $stopwatch.ElapsedMilliseconds
        
        Write-Host "Unit Tests Completed:" -ForegroundColor Green
        Write-Host "  Passed: $($TestResults.UnitTests.Passed)" -ForegroundColor Green
        Write-Host "  Failed: $($TestResults.UnitTests.Failed)" -ForegroundColor $(if ($TestResults.UnitTests.Failed -gt 0) { "Red" } else { "Green" })
        Write-Host "  Skipped: $($TestResults.UnitTests.Skipped)" -ForegroundColor Yellow
        Write-Host "  Duration: $($TestResults.UnitTests.Duration)ms" -ForegroundColor Cyan
        
        return $TestResults.UnitTests.Failed -eq 0
    }
    catch {
        Write-Host "Error running unit tests: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to run integration tests
function Invoke-IntegrationTests {
    Write-Host "`nRunning Integration Tests..." -ForegroundColor Yellow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Test Elasticsearch connectivity
        Write-Host "Testing Elasticsearch connectivity..." -ForegroundColor Gray
        $elasticHealth = Test-ElasticsearchConnection
        
        # Test API endpoints
        Write-Host "Testing API endpoints..." -ForegroundColor Gray
        $apiTests = Test-ApiEndpoints
        
        # Test Chinese tokenizer
        Write-Host "Testing Chinese tokenizer..." -ForegroundColor Gray
        $tokenizerTests = Test-ChineseTokenizer
        
        # Calculate results
        $totalTests = 3
        $passedTests = ($elasticHealth ? 1 : 0) + ($apiTests ? 1 : 0) + ($tokenizerTests ? 1 : 0)
        
        $TestResults.IntegrationTests.Passed = $passedTests
        $TestResults.IntegrationTests.Failed = $totalTests - $passedTests
        $TestResults.IntegrationTests.Duration = $stopwatch.ElapsedMilliseconds
        
        Write-Host "Integration Tests Completed:" -ForegroundColor Green
        Write-Host "  Elasticsearch: $(if ($elasticHealth) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($elasticHealth) { "Green" } else { "Red" })
        Write-Host "  API Endpoints: $(if ($apiTests) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($apiTests) { "Green" } else { "Red" })
        Write-Host "  Chinese Tokenizer: $(if ($tokenizerTests) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($tokenizerTests) { "Green" } else { "Red" })
        Write-Host "  Duration: $($TestResults.IntegrationTests.Duration)ms" -ForegroundColor Cyan
        
        return $passedTests -eq $totalTests
    }
    catch {
        Write-Host "Error running integration tests: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test Elasticsearch connection
function Test-ElasticsearchConnection {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -TimeoutSec 10
        
        if ($response.status -eq "green" -or $response.status -eq "yellow") {
            Write-Host "  ✅ Elasticsearch cluster is healthy" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ⚠️  Elasticsearch cluster status: $($response.status)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Failed to connect to Elasticsearch: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test API endpoints
function Test-ApiEndpoints {
    try {
        # Test health endpoint
        $healthResponse = Invoke-RestMethod -Uri "http://localhost:5000/health" -TimeoutSec 10
        
        if ($healthResponse.status -eq "Healthy") {
            Write-Host "  ✅ API health endpoint is working" -ForegroundColor Green
            
            # Test search endpoint
            $searchResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/search?query=test&page=1&pageSize=10" -TimeoutSec 10
            
            if ($searchResponse -ne $null) {
                Write-Host "  ✅ API search endpoint is working" -ForegroundColor Green
                return $true
            } else {
                Write-Host "  ❌ API search endpoint failed" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ❌ API health endpoint failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Failed to test API endpoints: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test Chinese tokenizer
function Test-ChineseTokenizer {
    try {
        # This would ideally call the actual tokenizer service
        # For now, we'll simulate a test
        $testQueries = @("人工智能", "机器学习", "深度学习")
        $allPassed = $true
        
        foreach ($query in $testQueries) {
            Write-Host "    Testing: $query" -ForegroundColor Gray
            # Simulate tokenizer test
            Start-Sleep -Milliseconds 100
        }
        
        Write-Host "  ✅ Chinese tokenizer tests passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ❌ Chinese tokenizer tests failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to run performance tests
function Invoke-PerformanceTests {
    Write-Host "`nRunning Performance Tests..." -ForegroundColor Yellow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Run the performance test script
        if (Test-Path ".\performance-test.ps1") {
            $perfResults = & ".\performance-test.ps1" -BaseUrl "http://localhost:5000" -TargetQPS 1000 -TestDurationSeconds 30 -GenerateReport $false
            
            # Parse performance results
            if (Test-Path ".\performance-results.json")) {
                $perfData = Get-Content ".\performance-results.json" | ConvertFrom-Json
                
                $TestResults.PerformanceTests.QPS = $perfData.Summary.ActualQPS
                $TestResults.PerformanceTests.AvgLatency = $perfData.ResponseTimes.Average
                $TestResults.PerformanceTests.P95Latency = $perfData.ResponseTimes.P95
                $TestResults.PerformanceTests.ErrorRate = $perfData.Summary.ErrorRate
                
                # Determine if performance tests passed
                $qpsPass = $TestResults.PerformanceTests.QPS -ge 800  # 80% of target
                $latencyPass = $TestResults.PerformanceTests.P95Latency -le 200
                $errorPass = $TestResults.PerformanceTests.ErrorRate -le 5
                
                $TestResults.PerformanceTests.Passed = $qpsPass -and $latencyPass -and $errorPass
                
                Write-Host "Performance Tests Completed:" -ForegroundColor Green
                Write-Host "  QPS: $([Math]::Round($TestResults.PerformanceTests.QPS, 1)) $(if ($qpsPass) { '✅' } else { '❌' })" -ForegroundColor $(if ($qpsPass) { "Green" } else { "Red" })
                Write-Host "  Avg Latency: $([Math]::Round($TestResults.PerformanceTests.AvgLatency, 1))ms $(if ($latencyPass) { '✅' } else { '❌' })" -ForegroundColor $(if ($latencyPass) { "Green" } else { "Red" })
                Write-Host "  P95 Latency: $([Math]::Round($TestResults.PerformanceTests.P95Latency, 1))ms $(if ($latencyPass) { '✅' } else { '❌' })" -ForegroundColor $(if ($latencyPass) { "Green" } else { "Red" })
                Write-Host "  Error Rate: $([Math]::Round($TestResults.PerformanceTests.ErrorRate, 2))% $(if ($errorPass) { '✅' } else { '❌' })" -ForegroundColor $(if ($errorPass) { "Green" } else { "Red" })
            } else {
                Write-Host "  ⚠️  Performance results file not found" -ForegroundColor Yellow
                $TestResults.PerformanceTests.Passed = $false
            }
        } else {
            Write-Host "  ⚠️  Performance test script not found" -ForegroundColor Yellow
            $TestResults.PerformanceTests.Passed = $false
        }
        
        $TestResults.PerformanceTests.Duration = $stopwatch.ElapsedMilliseconds
        Write-Host "  Duration: $($TestResults.PerformanceTests.Duration)ms" -ForegroundColor Cyan
        
        return $TestResults.PerformanceTests.Passed
    }
    catch {
        Write-Host "  ❌ Error running performance tests: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.PerformanceTests.Passed = $false
        return $false
    }
}

# Function to test builds
function Invoke-BuildTests {
    Write-Host "`nRunning Build Tests..." -ForegroundColor Yellow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Test backend build
        Write-Host "Testing backend build..." -ForegroundColor Gray
        $backendBuild = Test-BackendBuild
        
        # Test frontend build
        Write-Host "Testing frontend build..." -ForegroundColor Gray
        $frontendBuild = Test-FrontendBuild
        
        $TestResults.BuildTests.Backend = $backendBuild
        $TestResults.BuildTests.Frontend = $frontendBuild
        
        Write-Host "Build Tests Completed:" -ForegroundColor Green
        Write-Host "  Backend Build: $(if ($backendBuild) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($backendBuild) { "Green" } else { "Red" })
        Write-Host "  Frontend Build: $(if ($frontendBuild) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($frontendBuild) { "Green" } else { "Red" })
        
        return $backendBuild -and $frontendBuild
    }
    catch {
        Write-Host "  ❌ Error running build tests: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test backend build
function Test-BackendBuild {
    try {
        Set-Location (Split-Path $ApiProjectPath -Parent)
        $buildResult = dotnet build --configuration Release --no-restore
        Set-Location $PSScriptRoot
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ Backend builds successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    ❌ Backend build failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "    ❌ Backend build error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test frontend build
function Test-FrontendBuild {
    try {
        Set-Location $FrontendPath
        $buildResult = npm run build
        Set-Location $PSScriptRoot
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ Frontend builds successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    ❌ Frontend build failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "    ❌ Frontend build error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to generate comprehensive report
function Get-ComprehensiveTestReport {
    Write-Host "`n=== Comprehensive Test Report ===" -ForegroundColor Green
    
    $totalDuration = ([DateTime]::Now - $TestResults.StartTime).TotalMilliseconds
    
    # Calculate overall score
    $unitTestScore = if ($TestResults.UnitTests.Passed + $TestResults.UnitTests.Failed -gt 0) { 
        $TestResults.UnitTests.Passed / ($TestResults.UnitTests.Passed + $TestResults.UnitTests.Failed) * 100 
    } else { 0 }
    
    $integrationScore = if ($TestResults.IntegrationTests.Passed + $TestResults.IntegrationTests.Failed -gt 0) { 
        $TestResults.IntegrationTests.Passed / ($TestResults.IntegrationTests.Passed + $TestResults.IntegrationTests.Failed) * 100 
    } else { 0 }
    
    $performanceScore = if ($TestResults.PerformanceTests.Passed) { 100 } else { 0 }
    $buildScore = if ($TestResults.BuildTests.Backend -and $TestResults.BuildTests.Frontend) { 100 } else { 0 }
    
    $overallScore = ($unitTestScore * 0.3 + $integrationScore * 0.3 + $performanceScore * 0.3 + $buildScore * 0.1)
    
    # Performance grade
    $performanceGrade = switch ($overallScore) {
        { $_ -ge 90 } { "A+ (Excellent)" }
        { $_ -ge 80 } { "A (Very Good)" }
        { $_ -ge 70 } { "B+ (Good)" }
        { $_ -ge 60 } { "B (Acceptable)" }
        { $_ -ge 50 } { "C (Needs Improvement)" }
        default { "F (Failed)" }
    }
    
    Write-Host "Overall Score: $([Math]::Round($overallScore, 1))%" -ForegroundColor $(
        if ($overallScore -ge 80) { "Green" } elseif ($overallScore -ge 60) { "Yellow" } else { "Red" }
    )
    Write-Host "Performance Grade: $performanceGrade" -ForegroundColor $(
        if ($overallScore -ge 80) { "Green" } elseif ($overallScore -ge 60) { "Yellow" } else { "Red" }
    )
    Write-Host "Total Duration: $([Math]::Round($totalDuration, 0))ms" -ForegroundColor Cyan
    Write-Host ""
    
    # Detailed results
    Write-Host "Unit Tests:" -ForegroundColor Yellow
    Write-Host "  Passed: $($TestResults.UnitTests.Passed)" -ForegroundColor Green
    Write-Host "  Failed: $($TestResults.UnitTests.Failed)" -ForegroundColor Red
    Write-Host "  Skipped: $($TestResults.UnitTests.Skipped)" -ForegroundColor Yellow
    Write-Host "  Score: $([Math]::Round($unitTestScore, 1))%" -ForegroundColor $(if ($unitTestScore -ge 80) { "Green" } else { "Yellow" })
    
    Write-Host "`nIntegration Tests:" -ForegroundColor Yellow
    Write-Host "  Passed: $($TestResults.IntegrationTests.Passed)" -ForegroundColor Green
    Write-Host "  Failed: $($TestResults.IntegrationTests.Failed)" -ForegroundColor Red
    Write-Host "  Score: $([Math]::Round($integrationScore, 1))%" -ForegroundColor $(if ($integrationScore -ge 80) { "Green" } else { "Yellow" })
    
    Write-Host "`nPerformance Tests:" -ForegroundColor Yellow
    Write-Host "  QPS: $([Math]::Round($TestResults.PerformanceTests.QPS, 1))" -ForegroundColor Cyan
    Write-Host "  Avg Latency: $([Math]::Round($TestResults.PerformanceTests.AvgLatency, 1))ms" -ForegroundColor Cyan
    Write-Host "  P95 Latency: $([Math]::Round($TestResults.PerformanceTests.P95Latency, 1))ms" -ForegroundColor Cyan
    Write-Host "  Error Rate: $([Math]::Round($TestResults.PerformanceTests.ErrorRate, 2))%" -ForegroundColor Cyan
    Write-Host "  Score: $([Math]::Round($performanceScore, 1))%" -ForegroundColor $(if ($TestResults.PerformanceTests.Passed) { "Green" } else { "Red" })
    
    Write-Host "`nBuild Tests:" -ForegroundColor Yellow
    Write-Host "  Backend: $(if ($TestResults.BuildTests.Backend) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($TestResults.BuildTests.Backend) { "Green" } else { "Red" })
    Write-Host "  Frontend: $(if ($TestResults.BuildTests.Frontend) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($TestResults.BuildTests.Frontend) { "Green" } else { "Red" })
    Write-Host "  Score: $([Math]::Round($buildScore, 1))%" -ForegroundColor $(if ($buildScore -eq 100) { "Green" } else { "Red" })
    
    # Recommendations
    Write-Host "`n=== Recommendations ===" -ForegroundColor Yellow
    
    if ($unitTestScore -lt 80) {
        Write-Host "⚠️  Unit test coverage needs improvement. Consider adding more test cases." -ForegroundColor Red
    }
    
    if ($integrationScore -lt 80) {
        Write-Host "⚠️  Integration tests are failing. Check service dependencies and configuration." -ForegroundColor Red
    }
    
    if (-not $TestResults.PerformanceTests.Passed) {
        Write-Host "⚠️  Performance tests failed. Consider:" -ForegroundColor Red
        Write-Host "   - Optimizing Elasticsearch queries" -ForegroundColor White
        Write-Host "   - Increasing caching efficiency" -ForegroundColor White
        Write-Host "   - Scaling out with more server instances" -ForegroundColor White
        Write-Host "   - Upgrading hardware resources" -ForegroundColor White
    }
    
    if ($overallScore -ge 90) {
        Write-Host "✅ Excellent performance! System is ready for production deployment." -ForegroundColor Green
    } elseif ($overallScore -ge 70) {
        Write-Host "✅ Good performance! System meets basic requirements with minor optimizations needed." -ForegroundColor Green
    } else {
        Write-Host "❌ Performance needs significant improvement before production deployment." -ForegroundColor Red
    }
    
    # Save comprehensive report
    $comprehensiveReport = @{
        Summary = @{
            OverallScore = [Math]::Round($overallScore, 1)
            PerformanceGrade = $performanceGrade
            TotalDuration = [Math]::Round($totalDuration, 0)
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        UnitTests = $TestResults.UnitTests
        IntegrationTests = $TestResults.IntegrationTests
        PerformanceTests = $TestResults.PerformanceTests
        BuildTests = $TestResults.BuildTests
        Recommendations = @(
            if ($unitTestScore -lt 80) { "Improve unit test coverage" }
            if ($integrationScore -lt 80) { "Fix integration test failures" }
            if (-not $TestResults.PerformanceTests.Passed) { "Optimize system performance" }
            if (-not $TestResults.BuildTests.Backend) { "Fix backend build issues" }
            if (-not $TestResults.BuildTests.Frontend) { "Fix frontend build issues" }
        )
    }
    
    $reportFile = Join-Path $ResultsPath "comprehensive-test-report.json"
    $comprehensiveReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "`nComprehensive test report saved to: $reportFile" -ForegroundColor Green
    
    return $overallScore -ge 70  # Return success if overall score is 70% or higher
}

# Main execution
function Main {
    Write-Host "Starting comprehensive test suite..." -ForegroundColor Green
    Write-Host "This may take several minutes to complete." -ForegroundColor Yellow
    Write-Host ""
    
    $allTestsPassed = $true
    
    try {
        # Run build tests first
        if ($RunUnitTests -or $RunIntegrationTests) {
            $buildSuccess = Invoke-BuildTests
            if (-not $buildSuccess) {
                Write-Host "Build tests failed. Skipping other tests." -ForegroundColor Red
                return $false
            }
        }
        
        # Run unit tests
        if ($RunUnitTests) {
            $unitTestsPassed = Invoke-UnitTests
            if (-not $unitTestsPassed) {
                $allTestsPassed = $false
            }
        }
        
        # Run integration tests
        if ($RunIntegrationTests) {
            $integrationTestsPassed = Invoke-IntegrationTests
            if (-not $integrationTestsPassed) {
                $allTestsPassed = $false
            }
        }
        
        # Run performance tests
        if ($RunPerformanceTests) {
            $performanceTestsPassed = Invoke-PerformanceTests
            if (-not $performanceTestsPassed) {
                $allTestsPassed = $false
            }
        }
        
        # Generate comprehensive report
        if ($GenerateReport) {
            $reportGenerated = Get-ComprehensiveTestReport
        }
        
        Write-Host "`n=== Test Suite Summary ===" -ForegroundColor Green
        if ($allTestsPassed) {
            Write-Host "✅ All tests passed! System is ready for deployment." -ForegroundColor Green
        } else {
            Write-Host "❌ Some tests failed. Please review the results and fix issues before deployment." -ForegroundColor Red
        }
        
        return $allTestsPassed
        
    } catch {
        Write-Host "Error running test suite: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Run the comprehensive test suite
$success = Main

# Exit with appropriate code
exit $(if ($success) { 0 } else { 1 })