-- Netflix SQL Analysis: Duration Analysis
-- Movie runtime and TV show season analysis

-- 1. Movie duration statistics
SELECT
    'All Movies' as category,
    COUNT(*) as count,
    MIN(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as min_minutes,
    MAX(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as max_minutes,
    ROUND(AVG(CAST(REPLACE(duration, ' min', '') AS INTEGER))::NUMERIC, 2) as avg_minutes,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as median_minutes,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as q1_minutes,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as q3_minutes
FROM netflix_titles
WHERE type = 'Movie' AND duration LIKE '%min%';

-- 2. Movie duration by genre (top 15 genres)
WITH movie_genres AS (
    SELECT
        TRIM(genre) as genre,
        CAST(REPLACE(duration, ' min', '') AS INTEGER) as minutes
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE type = 'Movie' AND duration LIKE '%min%' AND listed_in IS NOT NULL
),
genre_stats AS (
    SELECT
        genre,
        COUNT(*) as movie_count,
        ROUND(AVG(minutes)::NUMERIC, 1) as avg_minutes,
        MIN(minutes) as min_minutes,
        MAX(minutes) as max_minutes,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY minutes) as median_minutes
    FROM movie_genres
    GROUP BY genre
    HAVING COUNT(*) >= 20
)
SELECT * FROM genre_stats
ORDER BY avg_minutes DESC
LIMIT 15;

-- 3. Movie duration buckets
SELECT
    CASE
        WHEN minutes < 60 THEN 'Under 60 min (Short)'
        WHEN minutes BETWEEN 60 AND 89 THEN '60-89 min'
        WHEN minutes BETWEEN 90 AND 119 THEN '90-119 min (Standard)'
        WHEN minutes BETWEEN 120 AND 149 THEN '120-149 min (Long)'
        WHEN minutes BETWEEN 150 AND 179 THEN '150-179 min (Very Long)'
        ELSE '180+ min (Epic)'
    END as duration_bucket,
    COUNT(*) as movie_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM (
    SELECT CAST(REPLACE(duration, ' min', '') AS INTEGER) as minutes
    FROM netflix_titles
    WHERE type = 'Movie' AND duration LIKE '%min%'
) t
GROUP BY duration_bucket
ORDER BY
    CASE duration_bucket
        WHEN 'Under 60 min (Short)' THEN 1
        WHEN '60-89 min' THEN 2
        WHEN '90-119 min (Standard)' THEN 3
        WHEN '120-149 min (Long)' THEN 4
        WHEN '150-179 min (Very Long)' THEN 5
        ELSE 6
    END;

-- 4. Movie duration trends over time (by release year)
SELECT
    release_year,
    COUNT(*) as movie_count,
    ROUND(AVG(CAST(REPLACE(duration, ' min', '') AS INTEGER))::NUMERIC, 1) as avg_minutes,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as median_minutes
FROM netflix_titles
WHERE type = 'Movie' AND duration LIKE '%min%' AND release_year >= 1990
GROUP BY release_year
ORDER BY release_year;

-- 5. TV Show season statistics
SELECT
    'All TV Shows' as category,
    COUNT(*) as count,
    MIN(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER)) as min_seasons,
    MAX(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER)) as max_seasons,
    ROUND(AVG(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER))::NUMERIC, 2) as avg_seasons,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER)) as median_seasons
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%';

-- 6. TV Show seasons distribution
SELECT
    seasons,
    COUNT(*) as show_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM (
    SELECT CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) as seasons
    FROM netflix_titles
    WHERE type = 'TV Show' AND duration LIKE '%Season%'
) t
GROUP BY seasons
ORDER BY seasons;

-- 7. TV Show seasons by genre (top 15 genres)
WITH tv_genres AS (
    SELECT
        TRIM(genre) as genre,
        CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) as seasons
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE type = 'TV Show' AND duration LIKE '%Season%' AND listed_in IS NOT NULL
),
genre_stats AS (
    SELECT
        genre,
        COUNT(*) as show_count,
        ROUND(AVG(seasons)::NUMERIC, 2) as avg_seasons,
        MIN(seasons) as min_seasons,
        MAX(seasons) as max_seasons
    FROM tv_genres
    GROUP BY genre
    HAVING COUNT(*) >= 10
)
SELECT * FROM genre_stats
ORDER BY avg_seasons DESC
LIMIT 15;

-- 8. TV Show seasons trend over time
SELECT
    release_year,
    COUNT(*) as show_count,
    ROUND(AVG(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER))::NUMERIC, 2) as avg_seasons
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%' AND release_year >= 2000
GROUP BY release_year
ORDER BY release_year;

-- 9. Long-running TV shows (5+ seasons)
SELECT
    title,
    CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) as seasons,
    release_year,
    listed_in as genres,
    rating
FROM netflix_titles
WHERE type = 'TV Show'
AND duration LIKE '%Season%'
AND CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) >= 5
ORDER BY seasons DESC, title
LIMIT 30;

-- 10. Short-form content analysis (Movies under 60 min, Shows with 1 season)
SELECT
    'Short Movies (<60 min)' as category,
    COUNT(*) as count
FROM netflix_titles
WHERE type = 'Movie' AND duration LIKE '%min%'
AND CAST(REPLACE(duration, ' min', '') AS INTEGER) < 60
UNION ALL
SELECT
    'Limited Series (1 Season)' as category,
    COUNT(*) as count
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%'
AND CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) = 1
UNION ALL
SELECT
    'Mini-Series (2-3 Seasons)' as category,
    COUNT(*) as count
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%'
AND CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) BETWEEN 2 AND 3
UNION ALL
SELECT
    'Standard Series (4-6 Seasons)' as category,
    COUNT(*) as count
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%'
AND CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) BETWEEN 4 AND 6
UNION ALL
SELECT
    'Long-Running (7+ Seasons)' as category,
    COUNT(*) as count
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%'
AND CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) >= 7;

-- 11. Duration vs Rating correlation (Movies)
SELECT
    CASE
        WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
        WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
        WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
        WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
        ELSE 'Unrated/Other'
    END as rating_category,
    COUNT(*) as movie_count,
    ROUND(AVG(CAST(REPLACE(duration, ' min', '') AS INTEGER))::NUMERIC, 1) as avg_minutes,
    MIN(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as min_minutes,
    MAX(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as max_minutes
FROM netflix_titles
WHERE type = 'Movie' AND duration LIKE '%min%' AND rating IS NOT NULL
GROUP BY rating_category
ORDER BY avg_minutes DESC;

-- 12. Duration vs Rating correlation (TV Shows)
SELECT
    CASE
        WHEN rating IN ('TV-Y', 'TV-Y7', 'TV-G') THEN 'Children'
        WHEN rating IN ('TV-PG', 'G', 'PG') THEN 'Family'
        WHEN rating IN ('TV-14', 'PG-13') THEN 'Teens'
        WHEN rating IN ('TV-MA', 'R', 'NC-17') THEN 'Mature'
        ELSE 'Unrated/Other'
    END as rating_category,
    COUNT(*) as show_count,
    ROUND(AVG(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER))::NUMERIC, 2) as avg_seasons
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%' AND rating IS NOT NULL
GROUP BY rating_category
ORDER BY avg_seasons DESC;