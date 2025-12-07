# Setup-SearchEngine.ps1

Write-Host "Initializing Search Engine Environment..." -ForegroundColor Cyan

# 1. Check for Go
if (Get-Command go -ErrorAction SilentlyContinue) {
    Write-Host "Go is installed." -ForegroundColor Green
    go version
} else {
    Write-Host "Go is NOT installed. Please install Go 1.21+ from https://go.dev/dl/" -ForegroundColor Red
    exit 1
}

# 2. Check for Node.js
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "Node.js is installed." -ForegroundColor Green
    node --version
} else {
    Write-Host "Node.js is NOT installed. Please install Node.js 18+ from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# 3. Setup Backend
Write-Host "`nSetting up Backend..." -ForegroundColor Cyan
Set-Location "backend"
if (Test-Path "go.mod") {
    Write-Host "Downloading Go dependencies..."
    go mod tidy
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Backend dependencies installed." -ForegroundColor Green
    } else {
        Write-Host "Failed to install backend dependencies." -ForegroundColor Red
    }
} else {
    Write-Host "go.mod not found in backend directory." -ForegroundColor Red
}

# 4. Setup Frontend
Write-Host "`nSetting up Frontend..." -ForegroundColor Cyan
Set-Location "..\frontend"
if (Test-Path "package.json") {
    Write-Host "Installing Node.js dependencies..."
    npm install
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Frontend dependencies installed." -ForegroundColor Green
    } else {
        Write-Host "Failed to install frontend dependencies." -ForegroundColor Red
    }
} else {
    Write-Host "package.json not found in frontend directory." -ForegroundColor Red
}

# 5. Environment Configuration Reminder
Write-Host "`nSetup Complete!" -ForegroundColor Green
Write-Host "Please ensure Elasticsearch (http://localhost:9200) and Redis (localhost:6379) are running."
Write-Host "To start backend: cd backend; go run cmd/server/main.go"
Write-Host "To start frontend: cd frontend; npm run dev"
