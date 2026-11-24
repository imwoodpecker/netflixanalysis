<#
.SYNOPSIS
    Netflix SQL Analysis - Database Setup Script (PowerShell for Windows)
.DESCRIPTION
    This script sets up the PostgreSQL database and loads the Netflix data.
.NOTES
    Requires PostgreSQL client tools (psql) in PATH.
#>

param(
    [string]$DbName = "netflix_analysis",
    [string]$DbUser = $env:POSTGRES_USER ?? "postgres",
    [string]$DbHost = $env:POSTGRES_HOST ?? "localhost",
    [string]$DbPort = $env:POSTGRES_PORT ?? "5432"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Netflix SQL Analysis - Database Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Database: $DbName"
Write-Host "User: $DbUser"
Write-Host "Host: $DbHost:$DbPort"
Write-Host ""

# Check if PostgreSQL is running
Write-Host "Checking PostgreSQL connection..." -ForegroundColor Yellow
try {
    & pg_isready -h $DbHost -p $DbPort -U $DbUser -d postgres -q
    Write-Host "PostgreSQL connection OK" -ForegroundColor Green
}
catch {
    Write-Error "ERROR: Cannot connect to PostgreSQL at $DbHost:$DbPort"
    Write-Error "Please ensure PostgreSQL is running and pg_isready is in PATH."
    exit 1
}

# Create database if it doesn't exist
Write-Host "Creating database '$DbName' if not exists..." -ForegroundColor Yellow
try {
    & psql -h $DbHost -p $DbPort -U $DbUser -d postgres -c "CREATE DATABASE $DbName;" 2>$null
    Write-Host "Database created or already exists" -ForegroundColor Green
}
catch {
    Write-Host "Database may already exist, continuing..." -ForegroundColor Yellow
}

$SqlDir = Join-Path (Split-Path $PSScriptRoot -Parent) "sql"
$DataDir = Join-Path (Split-Path $PSScriptRoot -Parent) "data"

# Run schema setup
Write-Host "Running schema setup..." -ForegroundColor Yellow
& psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f (Join-Path $SqlDir "01_schema_setup.sql")
Write-Host "Schema setup complete" -ForegroundColor Green

# Check for data file
$CsvFile = Join-Path $DataDir "netflix_titles.csv"
if (-not (Test-Path $CsvFile)) {
    Write-Warning "Data file not found at $CsvFile"
    Write-Warning "Please download the Netflix dataset from Kaggle:"
    Write-Warning "https://www.kaggle.com/datasets/shivamb/netflix-shows"
    Write-Warning "And place it at: $CsvFile"
    Write-Warning ""
    Write-Warning "Skipping data load. You can run it manually later with:"
    Write-Warning "  psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $SqlDir\02_data_loading.sql"
}
else {
    Write-Host "Loading data from $CsvFile..." -ForegroundColor Yellow
    & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "`copy netflix_titles FROM '$CsvFile' WITH (FORMAT csv, HEADER true);"

    Write-Host "Verifying data load..." -ForegroundColor Yellow
    & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "SELECT COUNT(*) as total_rows FROM netflix_titles;"
    Write-Host "Data load verified" -ForegroundColor Green
}

# Create materialized views
Write-Host "Creating materialized views..." -ForegroundColor Yellow
& psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f (Join-Path $SqlDir "views\materialized_views.sql")
Write-Host "Materialized views created" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Database setup complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run analysis queries: .\scripts\run_analysis.ps1"
Write-Host "2. Export results: python scripts\export_results.py"
Write-Host "3. Generate visualizations: jupyter notebook notebooks\netflix_visualization.ipynb"