-- Netflix SQL Analysis: Materialized Views
-- Pre-computed analytics views for dashboarding and reporting

-- 1. Genre Summary View
CREATE MATERIALIZED VIEW mv_genre_summary AS
WITH genre_exploded AS (
    SELECT
        TRIM(genre) as genre,
        type,
        show_id,
        release_year,
        rating,
        country
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
)
SELECT
    genre,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    COUNT(DISTINCT show_id) as unique_titles,
    COUNT(DISTINCT release_year) as years_span,
    MIN(release_year) as first_year,
    MAX(release_year) as latest_year,
    COUNT(DISTINCT TRIM(country)) as countries_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_catalog
FROM genre_exploded
GROUP BY genre
ORDER BY total_titles DESC;

CREATE INDEX idx_mv_genre_summary_genre ON mv_genre_summary(genre);

-- 2. Yearly Content Summary View
CREATE MATERIALIZED VIEW mv_yearly_summary AS
SELECT
    release_year,
    COUNT(*) as total_released,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies_released,
    COUNT(*) FILTER (WHERE type = 'TV Show') as shows_released,
    COUNT(DISTINCT TRIM(country)) as countries_represented,
    COUNT(DISTINCT TRIM(genre)) as genres_represented
FROM netflix_titles,
LATERAL unnest(string_to_array(listed_in, ', ')) as genre,
LATERAL unnest(string_to_array(country, ', ')) as country
WHERE listed_in IS NOT NULL AND country IS NOT NULL
GROUP BY release_year
ORDER BY release_year;

CREATE INDEX idx_mv_yearly_summary_year ON mv_yearly_summary(release_year);

-- 3. Country Summary View
CREATE MATERIALIZED VIEW mv_country_summary AS
WITH country_exploded AS (
    SELECT
        TRIM(country) as country,
        type,
        show_id,
        release_year,
        rating,
        listed_in
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL
)
SELECT
    country,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    COUNT(DISTINCT release_year) as years_span,
    MIN(release_year) as first_year,
    MAX(release_year) as latest_year,
    COUNT(DISTINCT TRIM(genre)) as genres_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_catalog
FROM country_exploded,
LATERAL unnest(string_to_array(listed_in, ', ')) as genre
WHERE listed_in IS NOT NULL
GROUP BY country
ORDER BY total_titles DESC;

CREATE INDEX idx_mv_country_summary_country ON mv_country_summary(country);

-- 4. Rating Summary View
CREATE MATERIALIZED VIEW mv_rating_summary AS
SELECT
    rating,
    type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY type), 2) as pct_within_type,
    MIN(release_year) as earliest_year,
    MAX(release_year) as latest_year,
    ROUND(AVG(CASE
        WHEN type = 'Movie' THEN CAST(REPLACE(duration, ' min', '') AS INTEGER)
        WHEN type = 'TV Show' THEN CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER)
    END)::NUMERIC, 2) as avg_duration
FROM netflix_titles
WHERE rating IS NOT NULL
GROUP BY rating, type
ORDER BY type, count DESC;

CREATE INDEX idx_mv_rating_summary_rating ON mv_rating_summary(rating);

-- 5. Monthly Addition Trends View
CREATE MATERIALIZED VIEW mv_monthly_additions AS
SELECT
    DATE_TRUNC('month', date_added) as month_start,
    EXTRACT(YEAR FROM date_added) as year,
    EXTRACT(MONTH FROM date_added) as month,
    COUNT(*) as titles_added,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies_added,
    COUNT(*) FILTER (WHERE type = 'TV Show') as shows_added,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', date_added)) as cumulative_total
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY DATE_TRUNC('month', date_added), EXTRACT(YEAR FROM date_added), EXTRACT(MONTH FROM date_added)
ORDER BY month_start;

CREATE INDEX idx_mv_monthly_additions_month ON mv_monthly_additions(month_start);

-- 6. Director Summary View
CREATE MATERIALIZED VIEW mv_director_summary AS
WITH director_exploded AS (
    SELECT
        TRIM(director) as director,
        type,
        show_id,
        release_year,
        listed_in,
        rating,
        country
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as director
    WHERE director IS NOT NULL
)
SELECT
    director,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    COUNT(DISTINCT release_year) as years_active,
    MIN(release_year) as first_year,
    MAX(release_year) as latest_year,
    COUNT(DISTINCT TRIM(genre)) as genres_count,
    COUNT(DISTINCT TRIM(country)) as countries_count
FROM director_exploded,
LATERAL unnest(string_to_array(listed_in, ', ')) as genre,
LATERAL unnest(string_to_array(country, ', ')) as country
WHERE listed_in IS NOT NULL AND country IS NOT NULL
GROUP BY director
HAVING COUNT(*) >= 2
ORDER BY total_titles DESC;

CREATE INDEX idx_mv_director_summary_director ON mv_director_summary(director);

-- 7. Actor Summary View
CREATE MATERIALIZED VIEW mv_actor_summary AS
WITH actor_exploded AS (
    SELECT
        TRIM(cast_member) as actor,
        type,
        show_id,
        release_year,
        listed_in,
        rating
    FROM netflix_titles,
    LATERAL unnest(string_to_array(cast, ', ')) as cast_member
    WHERE cast IS NOT NULL
)
SELECT
    actor,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    COUNT(DISTINCT release_year) as years_active,
    MIN(release_year) as first_year,
    MAX(release_year) as latest_year,
    COUNT(DISTINCT TRIM(genre)) as genres_count
FROM actor_exploded,
LATERAL unnest(string_to_array(listed_in, ', ')) as genre
WHERE listed_in IS NOT NULL
GROUP BY actor
HAVING COUNT(*) >= 3
ORDER BY total_titles DESC;

CREATE INDEX idx_mv_actor_summary_actor ON mv_actor_summary(actor);

-- 8. Genre-Country Matrix View
CREATE MATERIALIZED VIEW mv_genre_country_matrix AS
SELECT
    TRIM(genre) as genre,
    TRIM(country) as country,
    COUNT(*) as title_count
FROM netflix_titles,
LATERAL unnest(string_to_array(listed_in, ', ')) as genre,
LATERAL unnest(string_to_array(country, ', ')) as country
WHERE listed_in IS NOT NULL AND country IS NOT NULL
GROUP BY TRIM(genre), TRIM(country)
HAVING COUNT(*) >= 5
ORDER BY title_count DESC;

CREATE INDEX idx_mv_gc_matrix_genre ON mv_genre_country_matrix(genre);
CREATE INDEX idx_mv_gc_matrix_country ON mv_genre_country_matrix(country);

-- 9. Duration Statistics View
CREATE MATERIALIZED VIEW mv_duration_stats AS
SELECT
    type,
    CASE
        WHEN type = 'Movie' THEN
            CAST(REPLACE(duration, ' min', '') AS INTEGER)
        WHEN type = 'TV Show' THEN
            CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) * 60 -- approximate
    END as duration_minutes,
    release_year,
    rating,
    TRIM(genre) as genre
FROM netflix_titles,
LATERAL unnest(string_to_array(listed_in, ', ')) as genre
WHERE duration IS NOT NULL
AND ((type = 'Movie' AND duration LIKE '%min%')
     OR (type = 'TV Show' AND duration LIKE '%Season%'))
AND listed_in IS NOT NULL;

CREATE INDEX idx_mv_duration_stats_type ON mv_duration_stats(type);
CREATE INDEX idx_mv_duration_stats_year ON mv_duration_stats(release_year);

-- 10. Content Age View (lag between release and Netflix addition)
CREATE MATERIALIZED VIEW mv_content_age AS
SELECT
    show_id,
    title,
    type,
    release_year,
    EXTRACT(YEAR FROM date_added) as year_added,
    EXTRACT(YEAR FROM date_added) - release_year as age_at_addition,
    CASE
        WHEN EXTRACT(YEAR FROM date_added) - release_year <= 1 THEN 'New Release (0-1 yr)'
        WHEN EXTRACT(YEAR FROM date_added) - release_year <= 5 THEN 'Recent (2-5 yr)'
        WHEN EXTRACT(YEAR FROM date_added) - release_year <= 10 THEN 'Modern (6-10 yr)'
        WHEN EXTRACT(YEAR FROM date_added) - release_year <= 20 THEN 'Classic (11-20 yr)'
        ELSE 'Vintage (20+ yr)'
    END as age_category
FROM netflix_titles
WHERE date_added IS NOT NULL AND release_year > 0;

CREATE INDEX idx_mv_content_age_year ON mv_content_age(year_added);
CREATE INDEX idx_mv_content_age_category ON mv_content_age(age_category);

-- Refresh all materialized views
REFRESH MATERIALIZED VIEW mv_genre_summary;
REFRESH MATERIALIZED VIEW mv_yearly_summary;
REFRESH MATERIALIZED VIEW mv_country_summary;
REFRESH MATERIALIZED VIEW mv_rating_summary;
REFRESH MATERIALIZED VIEW mv_monthly_additions;
REFRESH MATERIALIZED VIEW mv_director_summary;
REFRESH MATERIALIZED VIEW mv_actor_summary;
REFRESH MATERIALIZED VIEW mv_genre_country_matrix;
REFRESH MATERIALIZED VIEW mv_duration_stats;
REFRESH MATERIALIZED VIEW mv_content_age;

-- Verify views
SELECT 'mv_genre_summary' as view_name, COUNT(*) as rows FROM mv_genre_summary
UNION ALL SELECT 'mv_yearly_summary', COUNT(*) FROM mv_yearly_summary
UNION ALL SELECT 'mv_country_summary', COUNT(*) FROM mv_country_summary
UNION ALL SELECT 'mv_rating_summary', COUNT(*) FROM mv_rating_summary
UNION ALL SELECT 'mv_monthly_additions', COUNT(*) FROM mv_monthly_additions
UNION ALL SELECT 'mv_director_summary', COUNT(*) FROM mv_director_summary
UNION ALL SELECT 'mv_actor_summary', COUNT(*) FROM mv_actor_summary
UNION ALL SELECT 'mv_genre_country_matrix', COUNT(*) FROM mv_genre_country_matrix
UNION ALL SELECT 'mv_duration_stats', COUNT(*) FROM mv_duration_stats
UNION ALL SELECT 'mv_content_age', COUNT(*) FROM mv_content_age;