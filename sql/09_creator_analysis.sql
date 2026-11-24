-- Netflix SQL Analysis: Creator Analysis
-- Director, cast, and content creator insights

-- 1. Top directors by title count
WITH director_exploded AS (
    SELECT
        TRIM(director) as director,
        type,
        show_id,
        release_year
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as director
    WHERE director IS NOT NULL
)
SELECT
    director,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    MIN(release_year) as first_year,
    MAX(release_year) as latest_year,
    RANK() OVER (ORDER BY COUNT(*) DESC) as director_rank
FROM director_exploded
GROUP BY director
HAVING COUNT(*) >= 3
ORDER BY total_titles DESC
LIMIT 30;

-- 2. Top directors by genre specialization
WITH director_genre AS (
    SELECT
        TRIM(d) as director,
        TRIM(g) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as d,
    LATERAL unnest(string_to_array(listed_in, ', ')) as g
    WHERE director IS NOT NULL AND listed_in IS NOT NULL
    GROUP BY TRIM(d), TRIM(g)
),
director_totals AS (
    SELECT director, SUM(count) as total
    FROM director_genre
    GROUP BY director
    HAVING SUM(count) >= 5
),
ranked_dg AS (
    SELECT
        dg.director,
        dg.genre,
        dg.count,
        ROUND(dg.count * 100.0 / dt.total, 2) as pct_of_director_work,
        ROW_NUMBER() OVER (PARTITION BY dg.director ORDER BY dg.count DESC) as rn
    FROM director_genre dg
    JOIN director_totals dt ON dg.director = dt.director
)
SELECT director, genre, count, pct_of_director_work
FROM ranked_dg
WHERE rn = 1
ORDER BY count DESC
LIMIT 25;

-- 3. Prolific director-actor collaborations
WITH director_cast AS (
    SELECT
        TRIM(d) as director,
        TRIM(c) as actor,
        COUNT(*) as collaborations
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as d,
    LATERAL unnest(string_to_array(cast, ', ')) as c
    WHERE director IS NOT NULL AND cast IS NOT NULL
    GROUP BY TRIM(d), TRIM(c)
    HAVING COUNT(*) >= 3
)
SELECT
    director,
    actor,
    collaborations
FROM director_cast
ORDER BY collaborations DESC
LIMIT 30;

-- 4. Top actors by title count
WITH cast_exploded AS (
    SELECT
        TRIM(cast_member) as actor,
        type,
        show_id,
        release_year
    FROM netflix_titles,
    LATERAL unnest(string_to_array(cast, ', ')) as cast_member
    WHERE cast IS NOT NULL
)
SELECT
    actor,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    MIN(release_year) as first_appearance,
    MAX(release_year) as latest_appearance,
    RANK() OVER (ORDER BY COUNT(*) DESC) as actor_rank
FROM cast_exploded
GROUP BY actor
HAVING COUNT(*) >= 5
ORDER BY total_titles DESC
LIMIT 30;

-- 5. Actor genre preferences
WITH actor_genre AS (
    SELECT
        TRIM(c) as actor,
        TRIM(g) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(cast, ', ')) as c,
    LATERAL unnest(string_to_array(listed_in, ', ')) as g
    WHERE cast IS NOT NULL AND listed_in IS NOT NULL
    GROUP BY TRIM(c), TRIM(g)
),
actor_totals AS (
    SELECT actor, SUM(count) as total
    FROM actor_genre
    GROUP BY actor
    HAVING SUM(count) >= 10
),
ranked_ag AS (
    SELECT
        ag.actor,
        ag.genre,
        ag.count,
        ROUND(ag.count * 100.0 / at.total, 2) as pct_of_actor_work,
        ROW_NUMBER() OVER (PARTITION BY ag.actor ORDER BY ag.count DESC) as rn
    FROM actor_genre ag
    JOIN actor_totals at ON ag.actor = at.actor
)
SELECT actor, genre, count, pct_of_actor_work
FROM ranked_ag
WHERE rn <= 3
ORDER BY actor, rn;

-- 6. Director rating preferences
WITH director_rating AS (
    SELECT
        TRIM(d) as director,
        CASE
            WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7') THEN 'Children/Family'
            WHEN rating IN ('PG', 'TV-PG') THEN 'Parental Guidance'
            WHEN rating IN ('PG-13', 'TV-14') THEN 'Teens/Young Adults'
            WHEN rating IN ('R', 'NC-17', 'TV-MA') THEN 'Mature/Adult'
            ELSE 'Unrated/Other'
        END as rating_category,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as d
    WHERE director IS NOT NULL AND rating IS NOT NULL
    GROUP BY TRIM(d), rating_category
),
director_totals AS (
    SELECT director, SUM(count) as total
    FROM director_rating
    GROUP BY director
    HAVING SUM(count) >= 5
)
SELECT
    dr.director,
    dr.rating_category,
    dr.count,
    ROUND(dr.count * 100.0 / dt.total, 2) as pct
FROM director_rating dr
JOIN director_totals dt ON dr.director = dt.director
ORDER BY dr.director, dr.count DESC;

-- 7. New vs. Established directors (by first appearance on Netflix)
WITH director_first_year AS (
    SELECT
        TRIM(director) as director,
        MIN(EXTRACT(YEAR FROM date_added)) as first_netflix_year,
        COUNT(*) as netflix_titles
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as director
    WHERE director IS NOT NULL AND date_added IS NOT NULL
    GROUP BY TRIM(director)
    HAVING COUNT(*) >= 2
)
SELECT
    CASE
        WHEN first_netflix_year >= 2020 THEN 'New (2020+)'
        WHEN first_netflix_year >= 2015 THEN 'Recent (2015-2019)'
        WHEN first_netflix_year >= 2010 THEN 'Established (2010-2014)'
        ELSE 'Veteran (pre-2010)'
    END as director_tier,
    COUNT(DISTINCT director) as director_count,
    SUM(netflix_titles) as total_titles,
    ROUND(AVG(netflix_titles)::NUMERIC, 2) as avg_titles_per_director
FROM director_first_year
GROUP BY director_tier
ORDER BY
    CASE director_tier
        WHEN 'Veteran (pre-2010)' THEN 1
        WHEN 'Established (2010-2014)' THEN 2
        WHEN 'Recent (2015-2019)' THEN 3
        ELSE 4
    END;

-- 8. International directors (non-US)
WITH director_country AS (
    SELECT
        TRIM(d) as director,
        TRIM(c) as country
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as d,
    LATERAL unnest(string_to_array(country, ', ')) as c
    WHERE director IS NOT NULL AND country IS NOT NULL
)
SELECT
    country,
    COUNT(DISTINCT director) as unique_directors,
    COUNT(*) as director_country_pairs
FROM director_country
WHERE country NOT ILIKE '%United States%'
GROUP BY country
ORDER BY unique_directors DESC
LIMIT 20;

-- 9. Director productivity over time
WITH director_yearly AS (
    SELECT
        TRIM(director) as director,
        release_year,
        COUNT(*) as titles_that_year
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as director
    WHERE director IS NOT NULL AND release_year >= 2000
    GROUP BY TRIM(director), release_year
),
director_peak AS (
    SELECT
        director,
        MAX(titles_that_year) as peak_year_output,
        release_year as peak_year
    FROM director_yearly
    GROUP BY director, release_year
    HAVING MAX(titles_that_year) >= 3
)
SELECT
    director,
    peak_year,
    peak_year_output
FROM director_peak
ORDER BY peak_year_output DESC, peak_year
LIMIT 20;

-- 10. Content creators with both directorial and acting credits
WITH directors AS (
    SELECT DISTINCT TRIM(director) as name
    FROM netflix_titles,
    LATERAL unnest(string_to_array(director, ', ')) as director
    WHERE director IS NOT NULL
),
actors AS (
    SELECT DISTINCT TRIM(cast_member) as name
    FROM netflix_titles,
    LATERAL unnest(string_to_array(cast, ', ')) as cast_member
    WHERE cast IS NOT NULL
)
SELECT
    d.name as director_actor,
    COUNT(DISTINCT dt.show_id) as directed_titles,
    COUNT(DISTINCT at.show_id) as acted_titles
FROM directors d
JOIN actors a ON d.name = a.name
JOIN netflix_titles dt ON dt.director ILIKE '%' || d.name || '%'
JOIN netflix_titles at ON at.cast ILIKE '%' || a.name || '%'
GROUP BY d.name
HAVING COUNT(DISTINCT dt.show_id) >= 1 AND COUNT(DISTINCT at.show_id) >= 1
ORDER BY (COUNT(DISTINCT dt.show_id) + COUNT(DISTINCT at.show_id)) DESC
LIMIT 20;