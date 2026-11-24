-- Netflix SQL Analysis: Genre Popularity Deep-Dive
-- Advanced genre analysis using array functions and window functions

-- 1. Overall genre popularity (all content)
WITH genre_exploded AS (
    SELECT
        TRIM(genre) as genre,
        type,
        show_id
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
)
SELECT
    genre,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_catalog,
    RANK() OVER (ORDER BY COUNT(*) DESC) as genre_rank
FROM genre_exploded
GROUP BY genre
ORDER BY total_titles DESC;

-- 2. Genre popularity by content type
WITH genre_by_type AS (
    SELECT
        TRIM(genre) as genre,
        type,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    GROUP BY TRIM(genre), type
),
ranked_genres AS (
    SELECT
        genre,
        type,
        count,
        RANK() OVER (PARTITION BY type ORDER BY count DESC) as type_rank
    FROM genre_by_type
)
SELECT * FROM ranked_genres
WHERE type_rank <= 15
ORDER BY type, type_rank;

-- 3. Genre trends over time (top 10 genres)
WITH top_genres AS (
    SELECT TRIM(genre) as genre
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    GROUP BY TRIM(genre)
    ORDER BY COUNT(*) DESC
    LIMIT 10
),
genre_yearly AS (
    SELECT
        release_year,
        TRIM(genre) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    AND TRIM(genre) IN (SELECT genre FROM top_genres)
    AND release_year >= 2000
    GROUP BY release_year, TRIM(genre)
)
SELECT * FROM genre_yearly
ORDER BY genre, release_year;

-- 4. Genre co-occurrence matrix (which genres appear together)
WITH genre_pairs AS (
    SELECT
        show_id,
        TRIM(g1) as genre1,
        TRIM(g2) as genre2
    FROM netflix_titles,
    LATERAL (
        SELECT
            genres[i] as g1,
            genres[j] as g2
        FROM generate_subscripts(string_to_array(listed_in, ', '), 1) as i,
        generate_subscripts(string_to_array(listed_in, ', '), 1) as j
        WHERE i < j
    ) pairs
    WHERE listed_in IS NOT NULL
    AND array_length(string_to_array(listed_in, ', '), 1) > 1
)
SELECT
    genre1,
    genre2,
    COUNT(DISTINCT show_id) as co_occurrence_count
FROM genre_pairs
GROUP BY genre1, genre2
ORDER BY co_occurrence_count DESC
LIMIT 30;

-- 5. Genre diversity per title
SELECT
    CASE
        WHEN genre_count = 1 THEN '1 genre'
        WHEN genre_count = 2 THEN '2 genres'
        WHEN genre_count = 3 THEN '3 genres'
        WHEN genre_count BETWEEN 4 AND 5 THEN '4-5 genres'
        ELSE '6+ genres'
    END as genre_breadth,
    COUNT(*) as title_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM (
    SELECT
        show_id,
        array_length(string_to_array(listed_in, ', '), 1) as genre_count
    FROM netflix_titles
    WHERE listed_in IS NOT NULL
) t
GROUP BY genre_breadth
ORDER BY
    CASE genre_breadth
        WHEN '1 genre' THEN 1
        WHEN '2 genres' THEN 2
        WHEN '3 genres' THEN 3
        WHEN '4-5 genres' THEN 4
        ELSE 5
    END;

-- 6. Genre by rating (content maturity)
WITH genre_rating AS (
    SELECT
        TRIM(genre) as genre,
        rating,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL AND rating IS NOT NULL
    GROUP BY TRIM(genre), rating
),
genre_totals AS (
    SELECT genre, SUM(count) as total
    FROM genre_rating
    GROUP BY genre
)
SELECT
    gr.genre,
    gr.rating,
    gr.count,
    ROUND(gr.count * 100.0 / gt.total, 2) as pct_within_genre
FROM genre_rating gr
JOIN genre_totals gt ON gr.genre = gt.total
WHERE gt.total >= 50  -- Only genres with significant volume
ORDER BY gr.genre, gr.count DESC;

-- 7. Top genres by country (US, India, UK)
WITH country_genre AS (
    SELECT
        TRIM(country) as country,
        TRIM(genre) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE country IS NOT NULL AND listed_in IS NOT NULL
    AND TRIM(country) IN ('United States', 'India', 'United Kingdom', 'Canada', 'Japan')
    GROUP BY TRIM(country), TRIM(genre)
),
ranked_country_genre AS (
    SELECT
        country,
        genre,
        count,
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY count DESC) as rn
    FROM country_genre
)
SELECT country, genre, count
FROM ranked_country_genre
WHERE rn <= 5
ORDER BY country, rn;