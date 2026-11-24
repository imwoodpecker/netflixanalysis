#!/bin/bash
# Netflix SQL Analysis: Run All Analysis Queries
# Executes all SQL analysis files and saves output

set -e

# Configuration
DB_NAME="${NETFLIX_DB_NAME:-netflix_analysis}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
SQL_DIR="$(dirname "$0")/../sql"
OUTPUT_DIR="$(dirname "$0")/../output"

echo "=========================================="
echo "Netflix SQL Analysis - Running Queries"
echo "=========================================="
echo "Database: $DB_NAME"
echo "Output: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Array of analysis files in order
ANALYSIS_FILES=(
    "03_exploratory_analysis.sql"
    "04_genre_analysis.sql"
    "05_temporal_analysis.sql"
    "06_geographic_analysis.sql"
    "07_rating_analysis.sql"
    "08_duration_analysis.sql"
    "09_creator_analysis.sql"
    "10_advanced_analytics.sql"
)

# Run each analysis file
for file in "${ANALYSIS_FILES[@]}"; do
    echo "Running $file..."
    OUTPUT_FILE="$OUTPUT_DIR/${file%.sql}_results.csv"

    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -f "$SQL_DIR/$file" \
        -o "$OUTPUT_FILE" \
        --csv

    if [ $? -eq 0 ]; then
        ROW_COUNT=$(tail -n +2 "$OUTPUT_FILE" | wc -l)
        echo "  ✓ Completed - $ROW_COUNT rows saved to $OUTPUT_FILE"
    else
        echo "  ✗ FAILED - Check errors above"
        exit 1
    fi
done

# Also run materialized view refresh
echo "Refreshing materialized views..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "REFRESH MATERIALIZED VIEW mv_genre_summary, mv_yearly_summary, mv_country_summary, mv_rating_summary, mv_monthly_additions, mv_director_summary, mv_actor_summary, mv_genre_country_matrix, mv_duration_stats, mv_content_age;"
echo "  ✓ Materialized views refreshed"

# Export materialized views to CSV
echo "Exporting materialized views..."
VIEWS=(
    "mv_genre_summary"
    "mv_yearly_summary"
    "mv_country_summary"
    "mv_rating_summary"
    "mv_monthly_additions"
    "mv_director_summary"
    "mv_actor_summary"
    "mv_genre_country_matrix"
    "mv_duration_stats"
    "mv_content_age"
)

for view in "${VIEWS[@]}"; do
    OUTPUT_FILE="$OUTPUT_DIR/${view}.csv"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "SELECT * FROM $view;" \
        -o "$OUTPUT_FILE" \
        --csv
    echo "  ✓ Exported $view"
done

echo ""
echo "=========================================="
echo "All analysis queries completed!"
echo "=========================================="
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Next step: python scripts/export_results.py"