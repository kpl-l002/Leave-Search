# IIS Application Request Routing (ARR) Configuration Script
# This script configures load balancing for high concurrency (1000+ QPS)

param(
    [string]$ServerFarmName = "SearchEngineFarm",
    [string[]]$BackendServers = @("localhost:5000", "localhost:5001", "localhost:5002"),
    [int]$LoadBalancingAlgorithm = 0, # 0=WeightedRoundRobin, 1=LeastRequests, 2=LeastResponseTime, 3=WeightedRoundRobin
    [bool]$EnableHealthCheck = $true
)

Write-Host "=== Configuring IIS Application Request Routing (ARR) ===" -ForegroundColor Green

# Install ARR if not already installed
Write-Host "Installing Application Request Routing..." -ForegroundColor Yellow
try {
    # Check if ARR is already installed
    $arrInstalled = Get-WindowsFeature -Name "Web-Application-Proxy" -ErrorAction SilentlyContinue
    if (-not $arrInstalled -or $arrInstalled.InstallState -ne "Installed") {
        # Install ARR using Web Platform Installer
        $webPiPath = "${env:ProgramFiles}\Microsoft\Web Platform Installer\WebPiCmd.exe"
        if (Test-Path $webPiPath) {
            & $webPiPath /install /products:"ARRv3_0" /accepteula
        } else {
            Write-Host "Web Platform Installer not found. Please install ARR manually." -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "Error installing ARR: $($_.Exception.Message)" -ForegroundColor Red
}

# Import IIS module
Import-Module WebAdministration

# Configure ARR settings
Write-Host "Configuring ARR global settings..." -ForegroundColor Yellow
try {
    # Enable proxy
    Set-WebConfigurationProperty -Filter "/system.webServer/proxy" -Name "enabled" -Value "true"
    
    # Configure timeout settings for high performance
    Set-WebConfigurationProperty -Filter "/system.webServer/proxy" -Name "timeout" -Value "00:00:30"
    Set-WebConfigurationProperty -Filter "/system.webServer/proxy" -Name "responseBufferLimit" -Value "0"
    
    # Configure caching for static content
    Set-WebConfigurationProperty -Filter "/system.webServer/proxy/caching" -Name "enabled" -Value "true"
    Set-WebConfigurationProperty -Filter "/system.webServer/proxy/caching" -Name "maxCacheSize" -Value "1000"
    
    # Configure load balancing
    Set-WebConfigurationProperty -Filter "/system.webServer/proxy/loadBalancing" -Name "algorithm" -Value $LoadBalancingAlgorithm
    
    Write-Host "ARR global settings configured successfully." -ForegroundColor Green
} catch {
    Write-Host "Error configuring ARR settings: $($_.Exception.Message)" -ForegroundColor Red
}

# Create server farm
Write-Host "Creating server farm: $ServerFarmName" -ForegroundColor Yellow
try {
    # Remove existing server farm if it exists
    if (Get-WebConfiguration -Filter "/webFarms/webFarm[@name='$ServerFarmName']" -ErrorAction SilentlyContinue) {
        Remove-WebConfiguration -Filter "/webFarms" -AtElement @{name="$ServerFarmName"}
    }
    
    # Create new server farm
    Add-WebConfiguration -Filter "/webFarms" -Value @{name="$ServerFarmName"}
    
    Write-Host "Server farm created successfully." -ForegroundColor Green
} catch {
    Write-Host "Error creating server farm: $($_.Exception.Message)" -ForegroundColor Red
}

# Add backend servers to farm
Write-Host "Adding backend servers to farm..." -ForegroundColor Yellow
foreach ($server in $BackendServers) {
    try {
        $address = $server.Split(':')[0]
        $port = if ($server.Split(':').Count -gt 1) { $server.Split(':')[1] } else { 80 }
        
        Add-WebConfiguration -Filter "/webFarms/webFarm[@name='$ServerFarmName']/server" -Value @{address="$address"; port="$port"}
        Write-Host "Added server: $server" -ForegroundColor Green
    } catch {
        Write-Host "Error adding server $server`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Configure health checking
if ($EnableHealthCheck) {
    Write-Host "Configuring health checking..." -ForegroundColor Yellow
    try {
        Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/healthCheck" -Name "url" -Value "/health"
        Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/healthCheck" -Name "interval" -Value "00:00:10"
        Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/healthCheck" -Name "timeout" -Value "00:00:05"
        Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/healthCheck" -Name "healthyStatusCodeRange" -Value "200-299"
        
        Write-Host "Health checking configured successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error configuring health checking: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Configure load balancing rules
Write-Host "Configuring load balancing rules..." -ForegroundColor Yellow
try {
    # Set load balancing algorithm
    Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/loadBalancing" -Name "algorithm" -Value $LoadBalancingAlgorithm
    
    # Configure server weights for weighted round robin
    if ($LoadBalancingAlgorithm -eq 0 -or $LoadBalancingAlgorithm -eq 3) {
        $servers = Get-WebConfiguration -Filter "/webFarms/webFarm[@name='$ServerFarmName']/server"
        $weight = 100
        foreach ($server in $servers) {
            Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/server[@address='$($server.address)']" -Name "weight" -Value $weight
        }
    }
    
    Write-Host "Load balancing rules configured successfully." -ForegroundColor Green
} catch {
    Write-Host "Error configuring load balancing rules: $($_.Exception.Message)" -ForegroundColor Red
}

# Create URL rewrite rules
Write-Host "Creating URL rewrite rules for load balancing..." -ForegroundColor Yellow
try {
    # Remove existing rewrite rules
    $rules = Get-WebConfiguration -Filter "/system.webServer/rewrite/rules/rule" 
    foreach ($rule in $rules) {
        if ($rule.name -like "*LoadBalance*") {
            Remove-WebConfiguration -Filter "/system.webServer/rewrite/rules/rule[@name='$($rule.name)']"
        }
    }
    
    # Create load balancing rule
    $rule = @"
    <rule name="SearchEngineLoadBalance" stopProcessing="true">
        <match url="^api/(.*)" />
        <conditions>
            <add input="{CACHE_STATUS}" pattern="HIT" negate="true" />
        </conditions>
        <action type="Rewrite" url="http://$ServerFarmName/{R:0}" />
    </rule>
"@
    
    Add-WebConfiguration -Filter "/system.webServer/rewrite/rules" -Value $rule
    
    Write-Host "URL rewrite rules created successfully." -ForegroundColor Green
} catch {
    Write-Host "Error creating URL rewrite rules: $($_.Exception.Message)" -ForegroundColor Red
}

# Configure caching for static content
Write-Host "Configuring output caching..." -ForegroundColor Yellow
try {
    # Enable output caching
    Set-WebConfigurationProperty -Filter "/system.webServer/caching" -Name "enabled" -Value "true"
    
    # Configure cache settings for high performance
    Set-WebConfigurationProperty -Filter "/system.webServer/caching" -Name "enableKernelCache" -Value "true"
    Set-WebConfigurationProperty -Filter "/system.webServer/caching" -Name "maxCacheSize" -Value "1000"
    
    # Create cache rules for API responses
    $cacheRule = @"
    <rule name="CacheAPIResponses">
        <match url="^api/(.*)" />
        <conditions>
            <add input="{REQUEST_METHOD}" pattern="^GET$" />
        </conditions>
        <action type="Cache" duration="00:00:30" />
    </rule>
"@
    
    Add-WebConfiguration -Filter "/system.webServer/caching/rules" -Value $cacheRule
    
    Write-Host "Output caching configured successfully." -ForegroundColor Green
} catch {
    Write-Host "Error configuring output caching: $($_.Exception.Message)" -ForegroundColor Red
}

# Configure SSL offloading
Write-Host "Configuring SSL offloading..." -ForegroundColor Yellow
try {
    Set-WebConfigurationProperty -Filter "/webFarms/webFarm[@name='$ServerFarmName']/applicationRequestRouting" -Name "sslOffload" -Value "true"
    
    Write-Host "SSL offloading configured successfully." -ForegroundColor Green
} catch {
    Write-Host "Error configuring SSL offloading: $($_.Exception.Message)" -ForegroundColor Red
}

# Restart IIS to apply changes
Write-Host "Restarting IIS to apply changes..." -ForegroundColor Yellow
try {
    Restart-Service -Name "W3SVC" -Force
    Write-Host "IIS restarted successfully." -ForegroundColor Green
} catch {
    Write-Host "Error restarting IIS: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "=== ARR Configuration Completed ===" -ForegroundColor Green
Write-Host "Server farm '$ServerFarmName' configured with $($BackendServers.Count) backend servers" -ForegroundColor Cyan
Write-Host "Load balancing algorithm: $LoadBalancingAlgorithm" -ForegroundColor Cyan
Write-Host "Health checking: $EnableHealthCheck" -ForegroundColor Cyan