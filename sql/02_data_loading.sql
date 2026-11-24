-- Netflix SQL Analysis: Data Loading
-- Run after schema_setup.sql

-- Method 1: Using PostgreSQL COPY command (fastest for local files)
-- Adjust path to your CSV file location
-- COPY netflix_titles FROM '/path/to/netflix_titles.csv'
--     WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '');

-- Method 2: Using psql \copy (works from client side)
-- \copy netflix_titles FROM 'data/netflix_titles.csv' WITH (FORMAT csv, HEADER true);

-- Method 3: Python script (see scripts/export_results.py) - recommended for portability

-- Verify data load
SELECT
    COUNT(*) as total_rows,
    COUNT(DISTINCT show_id) as unique_ids,
    MIN(release_year) as earliest_year,
    MAX(release_year) as latest_year,
    COUNT(DISTINCT type) as content_types
FROM netflix_titles;

-- Sample data check
SELECT * FROM netflix_titles LIMIT 5;

-- Check for NULLs in key columns
SELECT
    COUNT(*) FILTER (WHERE director IS NULL) as missing_director,
    COUNT(*) FILTER (WHERE cast IS NULL) as missing_cast,
    COUNT(*) FILTER (WHERE country IS NULL) as missing_country,
    COUNT(*) FILTER (WHERE date_added IS NULL) as missing_date_added,
    COUNT(*) FILTER (WHERE rating IS NULL) as missing_rating,
    COUNT(*) FILTER (WHERE duration IS NULL) as missing_duration,
    COUNT(*) FILTER (WHERE listed_in IS NULL) as missing_genres
FROM netflix_titles;