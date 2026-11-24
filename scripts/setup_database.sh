#!/bin/bash
# Netflix SQL Analysis: Database Setup Script
# This script sets up the PostgreSQL database and loads the data

set -e  # Exit on error

# Configuration
DB_NAME="netflix_analysis"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
SQL_DIR="$(dirname "$0")/../sql"
DATA_DIR="$(dirname "$0")/../data"

echo "=========================================="
echo "Netflix SQL Analysis - Database Setup"
echo "=========================================="
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Host: $DB_HOST:$DB_PORT"
echo ""

# Check if PostgreSQL is running
echo "Checking PostgreSQL connection..."
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to PostgreSQL at $DB_HOST:$DB_PORT"
    echo "Please ensure PostgreSQL is running and accessible."
    exit 1
fi
echo "PostgreSQL connection OK"

# Create database if it doesn't exist
echo "Creating database '$DB_NAME' if not exists..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database may already exist"

# Run schema setup
echo "Running schema setup..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_DIR/01_schema_setup.sql"

# Check for data file
CSV_FILE="$DATA_DIR/netflix_titles.csv"
if [ ! -f "$CSV_FILE" ]; then
    echo ""
    echo "WARNING: Data file not found at $CSV_FILE"
    echo "Please download the Netflix dataset from Kaggle:"
    echo "https://www.kaggle.com/datasets/shivamb/netflix-shows"
    echo "And place it at: $CSV_FILE"
    echo ""
    echo "Skipping data load. You can run it manually later with:"
    echo "  psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $SQL_DIR/02_data_loading.sql"
else
    echo "Loading data from $CSV_FILE..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\copy netflix_titles FROM '$CSV_FILE' WITH (FORMAT csv, HEADER true);"

    echo "Verifying data load..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) as total_rows FROM netflix_titles;"
fi

# Create materialized views
echo "Creating materialized views..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_DIR/views/materialized_views.sql"

echo ""
echo "=========================================="
echo "Database setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Run analysis queries: ./scripts/run_analysis.sh"
echo "2. Export results: python scripts/export_results.py"
echo "3. Generate visualizations: jupyter notebook notebooks/netflix_visualization.ipynb"