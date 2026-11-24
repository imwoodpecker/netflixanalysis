-- Netflix SQL Analysis: Schema Setup
-- Run this first to create the table and indexes

-- Drop table if exists (for clean reruns)
DROP TABLE IF EXISTS netflix_titles CASCADE;

-- Create main table
CREATE TABLE netflix_titles (
    show_id VARCHAR(10) PRIMARY KEY,
    type VARCHAR(20) NOT NULL,
    title VARCHAR(500) NOT NULL,
    director VARCHAR(500),
    cast TEXT,
    country VARCHAR(500),
    date_added DATE,
    release_year INTEGER NOT NULL,
    rating VARCHAR(20),
    duration VARCHAR(50),
    listed_in VARCHAR(500),
    description TEXT NOT NULL
);

-- Create indexes for performance
CREATE INDEX idx_netflix_type ON netflix_titles(type);
CREATE INDEX idx_netflix_release_year ON netflix_titles(release_year);
CREATE INDEX idx_netflix_date_added ON netflix_titles(date_added);
CREATE INDEX idx_netflix_rating ON netflix_titles(rating);
CREATE INDEX idx_netflix_country ON netflix_titles(country);
CREATE INDEX idx_netflix_type_year ON netflix_titles(type, release_year);
CREATE INDEX idx_netflix_type_rating ON netflix_titles(type, rating);

-- Verify table creation
SELECT 'Table created successfully' as status;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'netflix_titles'
ORDER BY ordinal_position;