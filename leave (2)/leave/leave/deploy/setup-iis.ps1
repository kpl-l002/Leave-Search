# Windows Server IIS 部署脚本
# 适用于 Windows Server 2019/2022/2025

param(
    [string]$SiteName = "SearchEngine",
    [string]$Port = "80",
    [string]$HttpsPort = "443",
    [string]$PhysicalPath = "C:\inetpub\wwwroot\SearchEngine",
    [string]$AppPoolName = "SearchEngineAppPool",
    [string]$CertThumbprint = ""
)

Write-Host "开始配置 IIS 部署..." -ForegroundColor Green

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "请以管理员身份运行此脚本！" -ForegroundColor Red
    exit 1
}

# 安装 IIS 和相关功能
Write-Host "安装 IIS 和相关功能..." -ForegroundColor Yellow
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Mgmt-Console, Web-Mgmt-Service, Web-Http-Redirect, Web-Http-Compression, Web-Filtering, Web-Performance, Web-Stat-Compression, Web-Dyn-Compression

# 安装 URL Rewrite 模块
Write-Host "安装 URL Rewrite 模块..." -ForegroundColor Yellow
$urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
$urlRewritePath = "$env:TEMP\rewrite_amd64_en-US.msi"

if (-not (Test-Path $urlRewritePath)) {
    Invoke-WebRequest -Uri $urlRewriteUrl -OutFile $urlRewritePath
}

Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $urlRewritePath, "/quiet", "/norestart" -Wait

# 安装 .NET Core Hosting Bundle
Write-Host "安装 .NET Core Hosting Bundle..." -ForegroundColor Yellow
$dotnetHostingUrl = "https://download.visualstudio.microsoft.com/download/pr/17b6759f-1af0-41bc-ab12-209ba0377779/e8d02195dbf1434b940e0f05ae086453/dotnet-hosting-8.0.8-win.exe"
$dotnetHostingPath = "$env:TEMP\dotnet-hosting-8.0.8-win.exe"

if (-not (Test-Path $dotnetHostingPath)) {
    Invoke-WebRequest -Uri $dotnetHostingUrl -OutFile $dotnetHostingPath
}

Start-Process -FilePath $dotnetHostingPath -ArgumentList "/quiet", "/norestart" -Wait

# 创建应用程序池
Write-Host "创建应用程序池..." -ForegroundColor Yellow
Import-Module WebAdministration

if (Test-Path "IIS:\AppPools\$AppPoolName") {
    Write-Host "应用程序池已存在，删除旧池..." -ForegroundColor Yellow
    Remove-WebAppPool -Name $AppPoolName
}

New-WebAppPool -Name $AppPoolName -Force
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "managedPipelineMode" -Value "Integrated"
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.loadUserProfile" -Value "true"
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.setProfileEnvironment" -Value "true"

# 设置应用程序池的CPU和内存限制
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "cpu.limit" -Value 0
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.idleTimeout" -Value "00:00:00"
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "recycling.periodicRestart.time" -Value "00:00:00"

# 创建网站目录
Write-Host "创建网站目录..." -ForegroundColor Yellow
if (-not (Test-Path $PhysicalPath)) {
    New-Item -ItemType Directory -Path $PhysicalPath -Force
}

# 复制发布文件到目标目录
Write-Host "复制发布文件..." -ForegroundColor Yellow
$sourcePath = Read-Host "请输入发布文件的路径 (例如: C:\publish)"

if (Test-Path $sourcePath) {
    Write-Host "正在复制文件到 $PhysicalPath..." -ForegroundColor Yellow
    Copy-Item -Path "$sourcePath\*" -Destination $PhysicalPath -Recurse -Force
} else {
    Write-Host "源路径不存在，请手动复制发布文件到 $PhysicalPath" -ForegroundColor Yellow
}

# 设置目录权限
Write-Host "设置目录权限..." -ForegroundColor Yellow
$acl = Get-Acl $PhysicalPath
$identity = "IIS AppPool\$AppPoolName"
$permission = $identity, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.SetAccessRule($accessRule)
Set-Acl $PhysicalPath $acl

# 创建网站
Write-Host "创建网站..." -ForegroundColor Yellow
if (Test-Path "IIS:\Sites\$SiteName") {
    Write-Host "网站已存在，删除旧网站..." -ForegroundColor Yellow
    Remove-WebSite -Name $SiteName
}

New-WebSite -Name $SiteName -PhysicalPath $PhysicalPath -Port $Port -ApplicationPool $AppPoolName -Force

# 配置HTTPS绑定
if ($CertThumbprint) {
    Write-Host "配置HTTPS绑定..." -ForegroundColor Yellow
    New-WebBinding -Name $SiteName -Protocol "https" -Port $HttpsPort -Thumbprint $CertThumbprint
} else {
    Write-Host "未提供证书指纹，跳过HTTPS配置" -ForegroundColor Yellow
}

# 配置请求过滤
Write-Host "配置请求过滤..." -ForegroundColor Yellow
Set-WebConfigurationProperty -Filter "/system.webServer/security/requestFiltering" -Name "maxAllowedContentLength" -Value 104857600 -Location $SiteName
Set-WebConfigurationProperty -Filter "/system.webServer/security/requestFiltering/requestLimits" -Name "maxQueryString" -Value 4096 -Location $SiteName
Set-WebConfigurationProperty -Filter "/system.webServer/security/requestFiltering/requestLimits" -Name "maxUrl" -Value 4096 -Location $SiteName

# 配置输出缓存
Write-Host "配置输出缓存..." -ForegroundColor Yellow
Add-WebConfiguration -Filter "/system.webServer/caching" -Value @{extension=".js";policy="CacheUntilChange";kernelCachePolicy="CacheUntilChange"} -Location $SiteName
Add-WebConfiguration -Filter "/system.webServer/caching" -Value @{extension=".css";policy="CacheUntilChange";kernelCachePolicy="CacheUntilChange"} -Location $SiteName

# 配置压缩
Write-Host "配置压缩..." -ForegroundColor Yellow
Set-WebConfigurationProperty -Filter "/system.webServer/urlCompression" -Name "doStaticCompression" -Value "true" -Location $SiteName
Set-WebConfigurationProperty -Filter "/system.webServer/urlCompression" -Name "doDynamicCompression" -Value "true" -Location $SiteName

# 配置日志
Write-Host "配置日志..." -ForegroundColor Yellow
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$SiteName']/logFile" -Name "directory" -Value "$PhysicalPath\logs"
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$SiteName']/logFile" -Name "logFormat" -Value "W3C"
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$SiteName']/logFile" -Name "period" -Value "Daily"

# 启动网站
Write-Host "启动网站..." -ForegroundColor Yellow
Start-WebSite -Name $SiteName

# 配置防火墙规则
Write-Host "配置防火墙规则..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "SearchEngine HTTP" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True
New-NetFirewallRule -DisplayName "SearchEngine HTTPS" -Direction Inbound -Protocol TCP -LocalPort $HttpsPort -Action Allow -Enabled True

# 验证部署
Write-Host "验证部署..." -ForegroundColor Yellow
$website = Get-WebSite -Name $SiteName
if ($website.State -eq "Started") {
    Write-Host "网站部署成功！" -ForegroundColor Green
    Write-Host "网站名称: $SiteName" -ForegroundColor Green
    Write-Host "HTTP地址: http://localhost:$Port" -ForegroundColor Green
    if ($CertThumbprint) {
        Write-Host "HTTPS地址: https://localhost:$HttpsPort" -ForegroundColor Green
    }
    Write-Host "物理路径: $PhysicalPath" -ForegroundColor Green
    Write-Host "应用程序池: $AppPoolName" -ForegroundColor Green
} else {
    Write-Host "网站部署失败，请检查配置" -ForegroundColor Red
}

Write-Host "部署完成！" -ForegroundColor Green
Write-Host "请确保:" -ForegroundColor Yellow
Write-Host "1. Elasticsearch 服务正在运行" -ForegroundColor Yellow
Write-Host "2. Redis 服务正在运行" -ForegroundColor Yellow
Write-Host "3. 配置文件中的连接字符串正确" -ForegroundColor Yellow
Write-Host "4. 防火墙规则已正确配置" -ForegroundColor Yellow