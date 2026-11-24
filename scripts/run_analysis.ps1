<#
.SYNOPSIS
    Netflix SQL Analysis - Run All Analysis Queries (PowerShell for Windows)
.DESCRIPTION
    Executes all SQL analysis files and saves output to CSV files.
#>

param(
    [string]$DbName = $env:NETFLIX_DB_NAME ?? "netflix_analysis",
    [string]$DbUser = $env:POSTGRES_USER ?? "postgres",
    [string]$DbHost = $env:POSTGRES_HOST ?? "localhost",
    [string]$DbPort = $env:POSTGRES_PORT ?? "5432"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Netflix SQL Analysis - Running Queries" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Database: $DbName"
Write-Host ""

$SqlDir = Join-Path (Split-Path $PSScriptRoot -Parent) "sql"
$OutputDir = Join-Path (Split-Path $PSScriptRoot -Parent) "output"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Array of analysis files in order
$AnalysisFiles = @(
    "03_exploratory_analysis.sql",
    "04_genre_analysis.sql",
    "05_temporal_analysis.sql",
    "06_geographic_analysis.sql",
    "07_rating_analysis.sql",
    "08_duration_analysis.sql",
    "09_creator_analysis.sql",
    "10_advanced_analytics.sql"
)

# Run each analysis file
foreach ($file in $AnalysisFiles) {
    Write-Host "Running $file..." -ForegroundColor Yellow
    $OutputFile = Join-Path $OutputDir ($file -replace '\.sql$', '_results.csv')

    try {
        & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f (Join-Path $SqlDir $file) -o $OutputFile --csv
        $RowCount = (Get-Content $OutputFile | Measure-Object -Line).Lines - 1  # Subtract header
        Write-Host "  ✓ Completed - $RowCount rows saved to $OutputFile" -ForegroundColor Green
    }
    catch {
        Write-Error "  ✗ FAILED - Check errors above"
        exit 1
    }
}

# Refresh materialized views
Write-Host "Refreshing materialized views..." -ForegroundColor Yellow
& psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "REFRESH MATERIALIZED VIEW mv_genre_summary, mv_yearly_summary, mv_country_summary, mv_rating_summary, mv_monthly_additions, mv_director_summary, mv_actor_summary, mv_genre_country_matrix, mv_duration_stats, mv_content_age;"
Write-Host "  ✓ Materialized views refreshed" -ForegroundColor Green

# Export materialized views to CSV
Write-Host "Exporting materialized views..." -ForegroundColor Yellow
$Views = @(
    "mv_genre_summary",
    "mv_yearly_summary",
    "mv_country_summary",
    "mv_rating_summary",
    "mv_monthly_additions",
    "mv_director_summary",
    "mv_actor_summary",
    "mv_genre_country_matrix",
    "mv_duration_stats",
    "mv_content_age"
)

foreach ($view in $Views) {
    $OutputFile = Join-Path $OutputDir "$view.csv"
    & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "SELECT * FROM $view;" -o $OutputFile --csv
    Write-Host "  ✓ Exported $view" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "All analysis queries completed!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Results saved to: $OutputDir" -ForegroundColor Green
Write-Host ""
Write-Host "Next step: python scripts\export_results.py" -ForegroundColor Yellow