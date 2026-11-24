-- Netflix SQL Analysis: Geographic Analysis
-- Content distribution across countries and regions

-- 1. Top countries by total content count
WITH country_exploded AS (
    SELECT
        TRIM(country) as country,
        type,
        show_id
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL
)
SELECT
    country,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_catalog,
    RANK() OVER (ORDER BY COUNT(*) DESC) as country_rank
FROM country_exploded
GROUP BY country
ORDER BY total_titles DESC
LIMIT 30;

-- 2. Content type ratio by country (top 20 countries)
WITH country_type AS (
    SELECT
        TRIM(country) as country,
        type,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL
    GROUP BY TRIM(country), type
),
country_totals AS (
    SELECT country, SUM(count) as total
    FROM country_type
    GROUP BY country
    HAVING SUM(count) >= 100  -- Filter for significant volume
)
SELECT
    ct.country,
    ct.type,
    ct.count,
    ROUND(ct.count * 100.0 / ctot.total, 2) as pct_within_country
FROM country_type ct
JOIN country_totals ctot ON ct.country = ctot.country
ORDER BY ctot.total DESC, ct.country, ct.type;

-- 3. Country genre preferences (top 5 genres per top 10 countries)
WITH country_genre AS (
    SELECT
        TRIM(c) as country,
        TRIM(g) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as c,
    LATERAL unnest(string_to_array(listed_in, ', ')) as g
    WHERE country IS NOT NULL AND listed_in IS NOT NULL
    GROUP BY TRIM(c), TRIM(g)
),
top_countries AS (
    SELECT country FROM country_genre
    GROUP BY country
    ORDER BY SUM(count) DESC
    LIMIT 10
),
ranked_genres AS (
    SELECT
        cg.country,
        cg.genre,
        cg.count,
        ROW_NUMBER() OVER (PARTITION BY cg.country ORDER BY cg.count DESC) as rn
    FROM country_genre cg
    JOIN top_countries tc ON cg.country = tc.country
)
SELECT country, genre, count
FROM ranked_genres
WHERE rn <= 5
ORDER BY country, rn;

-- 4. Regional analysis (grouping countries into regions)
WITH country_region AS (
    SELECT
        TRIM(country) as country,
        CASE
            WHEN TRIM(country) IN ('United States', 'Canada') THEN 'North America'
            WHEN TRIM(country) IN ('United Kingdom', 'France', 'Germany', 'Spain', 'Italy', 'Netherlands', 'Belgium', 'Sweden', 'Norway', 'Denmark', 'Finland', 'Poland', 'Turkey') THEN 'Europe'
            WHEN TRIM(country) IN ('India', 'Japan', 'South Korea', 'China', 'Hong Kong', 'Taiwan', 'Thailand', 'Philippines', 'Indonesia', 'Malaysia', 'Singapore', 'Vietnam') THEN 'Asia Pacific'
            WHEN TRIM(country) IN ('Brazil', 'Mexico', 'Argentina', 'Colombia', 'Chile', 'Peru', 'Venezuela') THEN 'Latin America'
            WHEN TRIM(country) IN ('South Africa', 'Nigeria', 'Egypt', 'Kenya', 'Ghana', 'Morocco') THEN 'Africa'
            WHEN TRIM(country) IN ('Australia', 'New Zealand') THEN 'Oceania'
            ELSE 'Other'
        END as region
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL
)
SELECT
    region,
    COUNT(*) as total_titles,
    COUNT(*) FILTER (WHERE type = 'Movie') as movies,
    COUNT(*) FILTER (WHERE type = 'TV Show') as tv_shows,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_catalog
FROM country_region cr
JOIN netflix_titles nt ON nt.show_id = nt.show_id  -- self join to get type
GROUP BY region
ORDER BY total_titles DESC;

-- 5. International co-productions (titles with multiple countries)
SELECT
    CASE
        WHEN country_count = 1 THEN 'Single Country'
        WHEN country_count = 2 THEN '2 Countries'
        WHEN country_count = 3 THEN '3 Countries'
        WHEN country_count BETWEEN 4 AND 5 THEN '4-5 Countries'
        ELSE '6+ Countries'
    END as production_scope,
    COUNT(*) as title_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM (
    SELECT
        show_id,
        array_length(string_to_array(country, ', '), 1) as country_count
    FROM netflix_titles
    WHERE country IS NOT NULL
) t
GROUP BY production_scope
ORDER BY
    CASE production_scope
        WHEN 'Single Country' THEN 1
        WHEN '2 Countries' THEN 2
        WHEN '3 Countries' THEN 3
        WHEN '4-5 Countries' THEN 4
        ELSE 5
    END;

-- 6. Country content addition timeline (top 5 countries)
WITH top_countries AS (
    SELECT TRIM(country) as country
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL
    GROUP BY TRIM(country)
    ORDER BY COUNT(*) DESC
    LIMIT 5
),
country_yearly AS (
    SELECT
        TRIM(country) as country,
        EXTRACT(YEAR FROM date_added) as year_added,
        COUNT(*) as titles_added
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL AND date_added IS NOT NULL
    AND TRIM(country) IN (SELECT country FROM top_countries)
    GROUP BY TRIM(country), EXTRACT(YEAR FROM date_added)
)
SELECT * FROM country_yearly
ORDER BY country, year_added;

-- 7. Content per capita proxy (titles per country relative to population)
-- Note: This is a simplified proxy using title count as proxy for investment
WITH country_stats AS (
    SELECT
        TRIM(country) as country,
        COUNT(*) as title_count,
        COUNT(DISTINCT type) as content_types
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country
    WHERE country IS NOT NULL
    GROUP BY TRIM(country)
    HAVING COUNT(*) >= 50
)
SELECT
    country,
    title_count,
    content_types,
    RANK() OVER (ORDER BY title_count DESC) as volume_rank
FROM country_stats
ORDER BY title_count DESC
LIMIT 25;

-- 8. Language/region inference from country groups
-- Asian content boom analysis
SELECT
    EXTRACT(YEAR FROM date_added) as year_added,
    COUNT(*) FILTER (WHERE country ILIKE '%India%') as india_content,
    COUNT(*) FILTER (WHERE country ILIKE '%South Korea%') as korea_content,
    COUNT(*) FILTER (WHERE country ILIKE '%Japan%') as japan_content,
    COUNT(*) FILTER (WHERE country ILIKE '%China%' OR country ILIKE '%Hong Kong%' OR country ILIKE '%Taiwan%') as china_content
FROM netflix_titles,
LATERAL unnest(string_to_array(country, ', ')) as country
WHERE date_added IS NOT NULL
AND EXTRACT(YEAR FROM date_added) >= 2015
GROUP BY EXTRACT(YEAR FROM date_added)
ORDER BY year_added;