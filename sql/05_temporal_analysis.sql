-- Netflix SQL Analysis: Temporal Analysis
-- Release patterns and content addition trends over time

-- 1. Content released by year (original release year)
SELECT
    release_year,
    COUNT(*) as titles_released,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) as pct_of_total
FROM netflix_titles
WHERE release_year >= 1950
GROUP BY release_year
ORDER BY release_year;

-- 2. Year-over-Year growth rate
WITH yearly_counts AS (
    SELECT
        release_year,
        COUNT(*) as titles_released
    FROM netflix_titles
    WHERE release_year >= 2000
    GROUP BY release_year
)
SELECT
    release_year,
    titles_released,
    LAG(titles_released) OVER (ORDER BY release_year) as prev_year,
    CASE
        WHEN LAG(titles_released) OVER (ORDER BY release_year) > 0
        THEN ROUND(
            (titles_released - LAG(titles_released) OVER (ORDER BY release_year)) * 100.0
            / LAG(titles_released) OVER (ORDER BY release_year), 2
        )
        ELSE NULL
    END as yoy_growth_pct
FROM yearly_counts
ORDER BY release_year;

-- 3. Content added to Netflix by year (date_added)
SELECT
    EXTRACT(YEAR FROM date_added) as year_added,
    COUNT(*) as titles_added,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies_added,
    COUNT(*) FILTER (WHERE type = 'TV Show') as shows_added
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY EXTRACT(YEAR FROM date_added)
ORDER BY year_added;

-- 4. Lag between release and Netflix addition
SELECT
    release_year,
    EXTRACT(YEAR FROM date_added) as year_added,
    COUNT(*) as count,
    ROUND(AVG(EXTRACT(YEAR FROM date_added) - release_year)::NUMERIC, 1) as avg_lag_years
FROM netflix_titles
WHERE date_added IS NOT NULL AND release_year >= 1990
GROUP BY release_year, EXTRACT(YEAR FROM date_added)
ORDER BY release_year, year_added;

-- 5. Decade analysis
SELECT
    (release_year / 10) * 10 as decade,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    ROUND(AVG(CASE WHEN type = 'Movie'
        THEN CAST(REPLACE(duration, ' min', '') AS INTEGER) END)::NUMERIC, 1) as avg_movie_minutes,
    ROUND(AVG(CASE WHEN type = 'TV Show'
        THEN CAST(REPLACE(REPLACE(duration, ' Seasons', ''), ' Season', '') AS INTEGER) END)::NUMERIC, 1) as avg_tv_seasons
FROM netflix_titles
WHERE release_year >= 1950
GROUP BY decade
ORDER BY decade;

-- 6. Monthly addition patterns (seasonality)
SELECT
    TO_CHAR(date_added, 'Month') as month,
    EXTRACT(MONTH FROM date_added) as month_num,
    COUNT(*) as titles_added,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_year
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY month, month_num
ORDER BY month_num;

-- 7. Recent vs. Classic content ratio by year added
WITH content_age AS (
    SELECT
        EXTRACT(YEAR FROM date_added) as year_added,
        CASE
            WHEN EXTRACT(YEAR FROM date_added) - release_year <= 1 THEN 'New Release (0-1 yr)'
            WHEN EXTRACT(YEAR FROM date_added) - release_year <= 5 THEN 'Recent (2-5 yr)'
            WHEN EXTRACT(YEAR FROM date_added) - release_year <= 10 THEN 'Modern (6-10 yr)'
            WHEN EXTRACT(YEAR FROM date_added) - release_year <= 20 THEN 'Classic (11-20 yr)'
            ELSE 'Vintage (20+ yr)'
        END as content_age_category
    FROM netflix_titles
    WHERE date_added IS NOT NULL AND release_year > 0
)
SELECT
    year_added,
    content_age_category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY year_added), 2) as pct
FROM content_age
GROUP BY year_added, content_age_category
ORDER BY year_added,
    CASE content_age_category
        WHEN 'New Release (0-1 yr)' THEN 1
        WHEN 'Recent (2-5 yr)' THEN 2
        WHEN 'Modern (6-10 yr)' THEN 3
        WHEN 'Classic (11-20 yr)' THEN 4
        ELSE 5
    END;

-- 8. Peak content acquisition periods
WITH monthly_additions AS (
    SELECT
        DATE_TRUNC('month', date_added) as month_start,
        COUNT(*) as titles_added
    FROM netflix_titles
    WHERE date_added IS NOT NULL
    GROUP BY DATE_TRUNC('month', date_added)
),
ranked_months AS (
    SELECT
        month_start,
        titles_added,
        RANK() OVER (ORDER BY titles_added DESC) as rank
    FROM monthly_additions
)
SELECT
    TO_CHAR(month_start, 'YYYY-MM') as month,
    titles_added
FROM ranked_months
WHERE rank <= 10
ORDER BY titles_added DESC;

-- 9. Content velocity: cumulative additions over time
SELECT
    DATE_TRUNC('month', date_added) as month,
    COUNT(*) as monthly_additions,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', date_added)) as cumulative_total
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY DATE_TRUNC('month', date_added)
ORDER BY month;

-- 10. Release year vs. Add year heatmap data
SELECT
    release_year,
    EXTRACT(YEAR FROM date_added) as year_added,
    COUNT(*) as count
FROM netflix_titles
WHERE date_added IS NOT NULL
AND release_year >= 1990
AND EXTRACT(YEAR FROM date_added) >= 2015
GROUP BY release_year, EXTRACT(YEAR FROM date_added)
ORDER BY release_year, year_added;