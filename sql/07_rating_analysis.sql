-- Netflix SQL Analysis: Rating Distribution Analysis
-- Age rating patterns, trends, and content maturity analysis

-- 1. Overall rating distribution
SELECT
    rating,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM netflix_titles
WHERE rating IS NOT NULL
GROUP BY rating
ORDER BY count DESC;

-- 2. Rating distribution by content type
SELECT
    type,
    rating,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY type), 2) as pct_within_type
FROM netflix_titles
WHERE rating IS NOT NULL
GROUP BY type, rating
ORDER BY type, count DESC;

-- 3. Normalized rating categories (mapping to standard categories)
WITH normalized_ratings AS (
    SELECT
        show_id,
        type,
        release_year,
        CASE
            WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
            WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
            WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
            WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
            WHEN rating IN ('NR', 'UR', 'NOT RATED', 'UNRATED') THEN 'Unrated'
            ELSE 'Other'
        END as rating_category
    FROM netflix_titles
    WHERE rating IS NOT NULL
)
SELECT
    rating_category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM normalized_ratings
GROUP BY rating_category
ORDER BY count DESC;

-- 4. Rating trends over time (by release year)
WITH normalized_ratings AS (
    SELECT
        release_year,
        CASE
            WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
            WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
            WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
            WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
            WHEN rating IN ('NR', 'UR', 'NOT RATED', 'UNRATED') THEN 'Unrated'
            ELSE 'Other'
        END as rating_category
    FROM netflix_titles
    WHERE rating IS NOT NULL AND release_year >= 2000
)
SELECT
    release_year,
    rating_category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY release_year), 2) as pct_of_year
FROM normalized_ratings
GROUP BY release_year, rating_category
ORDER BY release_year, count DESC;

-- 5. Rating by genre (top 10 genres)
WITH genre_rating AS (
    SELECT
        TRIM(genre) as genre,
        CASE
            WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
            WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
            WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
            WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
            WHEN rating IN ('NR', 'UR', 'NOT RATED', 'UNRATED') THEN 'Unrated'
            ELSE 'Other'
        END as rating_category,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL AND rating IS NOT NULL
    GROUP BY TRIM(genre), rating_category
),
top_genres AS (
    SELECT genre FROM genre_rating
    GROUP BY genre
    ORDER BY SUM(count) DESC
    LIMIT 10
)
SELECT
    gr.genre,
    gr.rating_category,
    gr.count,
    ROUND(gr.count * 100.0 / SUM(gr.count) OVER (PARTITION BY gr.genre), 2) as pct_within_genre
FROM genre_rating gr
JOIN top_genres tg ON gr.genre = tg.genre
ORDER BY gr.genre, gr.count DESC;

-- 6. Rating by country (top 10 countries)
WITH country_rating AS (
    SELECT
        TRIM(country) as country,
        CASE
            WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
            WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
            WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
            WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
            WHEN rating IN ('NR', 'UR', 'NOT RATED', 'UNRATED') THEN 'Unrated'
            ELSE 'Other'
        END as rating_category,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL AND rating IS NOT NULL
    GROUP BY TRIM(country), rating_category
),
top_countries AS (
    SELECT country FROM country_rating
    GROUP BY country
    ORDER BY SUM(count) DESC
    LIMIT 10
)
SELECT
    cr.country,
    cr.rating_category,
    cr.count,
    ROUND(cr.count * 100.0 / SUM(cr.count) OVER (PARTITION BY cr.country), 2) as pct_within_country
FROM country_rating cr
JOIN top_countries tc ON cr.country = tc.country
ORDER BY cr.country, cr.count DESC;

-- 7. Mature content (TV-MA, R) trends over time
SELECT
    release_year,
    COUNT(*) FILTER (WHERE rating IN ('TV-MA', 'R', 'NC-17')) as mature_count,
    COUNT(*) as total_rated,
    ROUND(
        COUNT(*) FILTER (WHERE rating IN ('TV-MA', 'R', 'NC-17')) * 100.0
        / NULLIF(COUNT(*), 0), 2
    ) as mature_pct
FROM netflix_titles
WHERE rating IS NOT NULL AND release_year >= 2000
GROUP BY release_year
ORDER BY release_year;

-- 8. Children/Family content trends
SELECT
    release_year,
    COUNT(*) FILTER (WHERE rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7', 'PG', 'TV-PG')) as family_count,
    COUNT(*) as total_rated,
    ROUND(
        COUNT(*) FILTER (WHERE rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7', 'PG', 'TV-PG')) * 100.0
        / NULLIF(COUNT(*), 0), 2
    ) as family_pct
FROM netflix_titles
WHERE rating IS NOT NULL AND release_year >= 2000
GROUP BY release_year
ORDER BY release_year;

-- 9. Rating distribution for content added to Netflix by year
WITH normalized_ratings AS (
    SELECT
        EXTRACT(YEAR FROM date_added) as year_added,
        CASE
            WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
            WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
            WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
            WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
            WHEN rating IN ('NR', 'UR', 'NOT RATED', 'UNRATED') THEN 'Unrated'
            ELSE 'Other'
        END as rating_category
    FROM netflix_titles
    WHERE rating IS NOT NULL AND date_added IS NOT NULL
)
SELECT
    year_added,
    rating_category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY year_added), 2) as pct_of_year
FROM normalized_ratings
GROUP BY year_added, rating_category
ORDER BY year_added, count DESC;

-- 10. Unrated content analysis
SELECT
    type,
    COUNT(*) as unrated_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY type), 2) as pct_unrated
FROM netflix_titles
WHERE rating IN ('NR', 'UR', 'NOT RATED', 'UNRATED') OR rating IS NULL
GROUP BY type;

-- 11. Top genres for mature content (TV-MA, R)
WITH mature_genres AS (
    SELECT
        TRIM(genre) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    AND rating IN ('TV-MA', 'R', 'NC-17')
    GROUP BY TRIM(genre)
)
SELECT genre, count
FROM mature_genres
ORDER BY count DESC
LIMIT 20;

-- 12. Rating consistency: content with same title but different ratings (if any)
SELECT
    title,
    COUNT(DISTINCT rating) as rating_variants,
    STRING_AGG(DISTINCT rating, ', ') as ratings
FROM netflix_titles
WHERE rating IS NOT NULL
GROUP BY title
HAVING COUNT(DISTINCT rating) > 1
ORDER BY rating_variants DESC;