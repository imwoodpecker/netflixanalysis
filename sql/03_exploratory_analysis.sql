-- Netflix SQL Analysis: Exploratory Data Analysis
-- Basic exploration queries to understand the dataset

-- 1. Overall dataset summary
SELECT
    'Total Titles' as metric,
    COUNT(*)::TEXT as value
FROM netflix_titles
UNION ALL
SELECT
    'Movies',
    COUNT(*)::TEXT
FROM netflix_titles WHERE type = 'Movie'
UNION ALL
SELECT
    'TV Shows',
    COUNT(*)::TEXT
FROM netflix_titles WHERE type = 'TV Show'
UNION ALL
SELECT
    'Unique Countries',
    COUNT(DISTINCT TRIM(country))::TEXT
FROM netflix_titles WHERE country IS NOT NULL
UNION ALL
SELECT
    'Unique Genres',
    COUNT(DISTINCT TRIM(genre))::TEXT
FROM netflix_titles, LATERAL unnest(string_to_array(listed_in, ', ')) as genre
UNION ALL
SELECT
    'Year Range',
    MIN(release_year)::TEXT || ' - ' || MAX(release_year)::TEXT
FROM netflix_titles;

-- 2. Content type distribution
SELECT
    type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM netflix_titles
GROUP BY type
ORDER BY count DESC;

-- 3. Release year distribution (overall)
SELECT
    release_year,
    COUNT(*) as titles_released
FROM netflix_titles
GROUP BY release_year
ORDER BY release_year;

-- 4. Date added distribution (when content was added to Netflix)
SELECT
    EXTRACT(YEAR FROM date_added) as year_added,
    COUNT(*) as titles_added
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY EXTRACT(YEAR FROM date_added)
ORDER BY year_added;

-- 5. Top 20 countries by content count
SELECT
    TRIM(country) as country,
    COUNT(*) as title_count
FROM netflix_titles, LATERAL unnest(string_to_array(country, ', ')) as country
WHERE country IS NOT NULL
GROUP BY TRIM(country)
ORDER BY title_count DESC
LIMIT 20;

-- 6. Rating distribution
SELECT
    rating,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM netflix_titles
WHERE rating IS NOT NULL
GROUP BY rating
ORDER BY count DESC;

-- 7. Duration analysis - Movies (minutes)
SELECT
    'Movie' as type,
    MIN(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as min_duration,
    MAX(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as max_duration,
    ROUND(AVG(CAST(REPLACE(duration, ' min', '') AS INTEGER))::NUMERIC, 2) as avg_duration,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as median_duration
FROM netflix_titles
WHERE type = 'Movie' AND duration LIKE '%min%';

-- 8. Duration analysis - TV Shows (seasons)
SELECT
    'TV Show' as type,
    MIN(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER)) as min_seasons,
    MAX(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER)) as max_seasons,
    ROUND(AVG(CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER))::NUMERIC, 2) as avg_seasons
FROM netflix_titles
WHERE type = 'TV Show' AND duration LIKE '%Season%';

-- 9. Content added by month (seasonality)
SELECT
    TO_CHAR(date_added, 'Month') as month_name,
    EXTRACT(MONTH FROM date_added) as month_num,
    COUNT(*) as titles_added
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY month_name, month_num
ORDER BY month_num;

-- 10. Description length analysis
SELECT
    type,
    MIN(LENGTH(description)) as min_desc_length,
    MAX(LENGTH(description)) as max_desc_length,
    ROUND(AVG(LENGTH(description))::NUMERIC, 2) as avg_desc_length
FROM netflix_titles
GROUP BY type;