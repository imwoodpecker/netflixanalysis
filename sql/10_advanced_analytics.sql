-- Netflix SQL Analysis: Advanced Analytics
-- Window functions, percentiles, complex aggregations, and predictive insights

-- 1. Percentile analysis of movie durations
SELECT
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p50_median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY CAST(REPLACE(duration, ' min', '') AS INTEGER)) as p99
FROM netflix_titles
WHERE type = 'Movie' AND duration LIKE '%min%';

-- 2. Running total of content added over time
SELECT
    DATE_TRUNC('month', date_added) as month,
    COUNT(*) as monthly_additions,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', date_added)) as cumulative_total,
    ROUND(
        AVG(COUNT(*)) OVER (
            ORDER BY DATE_TRUNC('month', date_added)
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        )::NUMERIC, 2
    ) as six_month_moving_avg
FROM netflix_titles
WHERE date_added IS NOT NULL
GROUP BY DATE_TRUNC('month', date_added)
ORDER BY month;

-- 3. Genre momentum: growing vs. declining genres
WITH genre_yearly AS (
    SELECT
        release_year,
        TRIM(genre) as genre,
        COUNT(*) as count
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL AND release_year BETWEEN 2015 AND 2021
    GROUP BY release_year, TRIM(genre)
),
genre_trends AS (
    SELECT
        genre,
        COUNT(*) as years_present,
        MIN(count) as min_yearly,
        MAX(count) as max_yearly,
        MAX(release_year) FILTER (WHERE count = (SELECT MAX(count) FROM genre_yearly gy2 WHERE gy2.genre = gy.genre)) as peak_year,
        -- Linear regression slope approximation
        (MAX(count) - MIN(count)) * 1.0 / NULLIF(MAX(release_year) - MIN(release_year), 0) as approx_slope
    FROM genre_yearly gy
    GROUP BY genre
    HAVING COUNT(*) >= 3
)
SELECT
    genre,
    years_present,
    min_yearly,
    max_yearly,
    peak_year,
    ROUND(approx_slope::NUMERIC, 2) as yearly_trend,
    CASE
        WHEN approx_slope > 5 THEN 'Strong Growth'
        WHEN approx_slope > 1 THEN 'Moderate Growth'
        WHEN approx_slope > -1 THEN 'Stable'
        WHEN approx_slope > -5 THEN 'Moderate Decline'
        ELSE 'Strong Decline'
    END as trend_category
FROM genre_trends
ORDER BY approx_slope DESC;

-- 4. Content clustering: similar titles based on genre overlap
WITH title_genres AS (
    SELECT
        show_id,
        title,
        type,
        ARRAY_AGG(TRIM(genre) ORDER BY TRIM(genre)) as genres
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    GROUP BY show_id, title, type
),
genre_similarity AS (
    SELECT
        t1.title as title_1,
        t2.title as title_2,
        t1.type,
        t2.type,
        ARRAY_LENGTH(t1.genres, 1) + ARRAY_LENGTH(t2.genres, 1) -
        ARRAY_LENGTH(ARRAY(SELECT DISTINCT unnest(t1.genres) INTERSECT SELECT DISTINCT unnest(t2.genres)), 1) as union_size,
        ARRAY_LENGTH(ARRAY(SELECT DISTINCT unnest(t1.genres) INTERSECT SELECT DISTINCT unnest(t2.genres)), 1) as intersection_size
    FROM title_genres t1
    JOIN title_genres t2 ON t1.show_id < t2.show_id AND t1.type = t2.type
    WHERE ARRAY_LENGTH(ARRAY(SELECT DISTINCT unnest(t1.genres) INTERSECT SELECT DISTINCT unnest(t2.genres)), 1) >= 3
)
SELECT
    title_1,
    title_2,
    type,
    intersection_size as shared_genres,
    ROUND(intersection_size * 1.0 / union_size, 3) as jaccard_similarity
FROM genre_similarity
ORDER BY jaccard_similarity DESC, intersection_size DESC
LIMIT 20;

-- 5. Market basket analysis: genre combinations
WITH genre_combos AS (
    SELECT
        show_id,
        ARRAY_AGG(TRIM(genre) ORDER BY TRIM(genre)) as genres
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    GROUP BY show_id
    HAVING ARRAY_LENGTH(ARRAY_AGG(TRIM(genre)), 1) >= 2
),
pair_counts AS (
    SELECT
        genres[i] as genre1,
        genres[j] as genre2,
        COUNT(*) as frequency
    FROM genre_combos,
    LATERAL generate_subscripts(genres, 1) as i,
    LATERAL generate_subscripts(genres, 1) as j
    WHERE i < j
    GROUP BY genres[i], genres[j]
),
genre_totals AS (
    SELECT TRIM(genre) as genre, COUNT(DISTINCT show_id) as total
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    GROUP BY TRIM(genre)
)
SELECT
    pc.genre1,
    pc.genre2,
    pc.frequency,
    gt1.total as genre1_total,
    gt2.total as genre2_total,
    ROUND(pc.frequency * 1.0 / gt1.total, 4) as confidence_1_to_2,
    ROUND(pc.frequency * 1.0 / gt2.total, 4) as confidence_2_to_1,
    ROUND(
        (pc.frequency * 1.0 / gt1.total) / (gt2.total * 1.0 / (SELECT COUNT(*) FROM netflix_titles)), 4
    ) as lift
FROM pair_counts pc
JOIN genre_totals gt1 ON pc.genre1 = gt1.genre
JOIN genre_totals gt2 ON pc.genre2 = gt2.genre
WHERE pc.frequency >= 50
ORDER BY lift DESC
LIMIT 20;

-- 6. Anomaly detection: unusual title characteristics
-- Movies with unusual duration for their genre
WITH genre_duration_stats AS (
    SELECT
        TRIM(genre) as genre,
        AVG(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as avg_duration,
        STDDEV(CAST(REPLACE(duration, ' min', '') AS INTEGER)) as stddev_duration
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE type = 'Movie' AND duration LIKE '%min%' AND listed_in IS NOT NULL
    GROUP BY TRIM(genre)
    HAVING COUNT(*) >= 20
),
movie_genre_zscore AS (
    SELECT
        nt.title,
        TRIM(g) as genre,
        CAST(REPLACE(nt.duration, ' min', '') AS INTEGER) as duration,
        gds.avg_duration,
        gds.stddev_duration,
        (CAST(REPLACE(nt.duration, ' min', '') AS INTEGER) - gds.avg_duration) / NULLIF(gds.stddev_duration, 0) as z_score
    FROM netflix_titles nt,
    LATERAL unnest(string_to_array(nt.listed_in, ', ')) as g
    JOIN genre_duration_stats gds ON TRIM(g) = gds.genre
    WHERE nt.type = 'Movie' AND nt.duration LIKE '%min%'
)
SELECT
    title,
    genre,
    duration,
    ROUND(avg_duration) as genre_avg,
    ROUND(z_score::NUMERIC, 2) as z_score
FROM movie_genre_zscore
WHERE ABS(z_score) > 2.5
ORDER BY ABS(z_score) DESC
LIMIT 20;

-- 7. Content gap analysis: genres by country vs global average
WITH global_genre_pct AS (
    SELECT
        TRIM(genre) as genre,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as global_pct
    FROM netflix_titles,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE listed_in IS NOT NULL
    GROUP BY TRIM(genre)
),
country_genre_pct AS (
    SELECT
        TRIM(country) as country,
        TRIM(genre) as genre,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY TRIM(country)) as country_pct
    FROM netflix_titles,
    LATERAL unnest(string_to_array(country, ', ')) as country,
    LATERAL unnest(string_to_array(listed_in, ', ')) as genre
    WHERE country IS NOT NULL AND listed_in IS NOT NULL
    GROUP BY TRIM(country), TRIM(genre)
),
top_countries AS (
    SELECT country FROM country_genre_pct
    GROUP BY country
    ORDER BY SUM(country_pct) DESC
    LIMIT 10
)
SELECT
    cgp.country,
    cgp.genre,
    ROUND(cgp.country_pct, 2) as country_pct,
    ROUND(ggp.global_pct, 2) as global_pct,
    ROUND(cgp.country_pct - ggp.global_pct, 2) as difference_pct,
    CASE
        WHEN cgp.country_pct - ggp.global_pct > 5 THEN 'Over-represented'
        WHEN cgp.country_pct - ggp.global_pct < -5 THEN 'Under-represented'
        ELSE 'Aligned'
    END as representation
FROM country_genre_pct cgp
JOIN global_genre_pct ggp ON cgp.genre = ggp.genre
JOIN top_countries tc ON cgp.country = tc.country
WHERE ABS(cgp.country_pct - ggp.global_pct) > 3
ORDER BY cgp.country, difference_pct DESC;

-- 8. Predictive: Content pipeline projection (simple linear trend)
WITH yearly_additions AS (
    SELECT
        EXTRACT(YEAR FROM date_added) as year,
        COUNT(*) as additions
    FROM netflix_titles
    WHERE date_added IS NOT NULL AND EXTRACT(YEAR FROM date_added) BETWEEN 2015 AND 2021
    GROUP BY EXTRACT(YEAR FROM date_added)
),
trend_calc AS (
    SELECT
        AVG(year) as avg_year,
        AVG(additions) as avg_additions,
        SUM((year - AVG(year) OVER ()) * (additions - AVG(additions) OVER ())) /
        SUM((year - AVG(year) OVER ())^2) as slope,
        AVG(additions) OVER () - (SUM((year - AVG(year) OVER ()) * (additions - AVG(additions) OVER ())) /
        SUM((year - AVG(year) OVER ())^2)) * AVG(year) OVER () as intercept
    FROM yearly_additions
    LIMIT 1
)
SELECT
    year,
    additions as actual,
    ROUND((slope * year + intercept)::NUMERIC) as projected
FROM yearly_additions, trend_calc
UNION ALL
SELECT
    2022 as year,
    NULL as actual,
    ROUND((slope * 2022 + intercept)::NUMERIC) as projected
FROM trend_calc
UNION ALL
SELECT
    2023 as year,
    NULL as actual,
    ROUND((slope * 2023 + intercept)::NUMERIC) as projected
FROM trend_calc
ORDER BY year;

-- 9. Cohort analysis: content added in same period
WITH cohorts AS (
    SELECT
        show_id,
        title,
        type,
        DATE_TRUNC('quarter', date_added) as cohort_quarter,
        DATE_TRUNC('quarter', date_added) as activity_quarter
    FROM netflix_titles
    WHERE date_added IS NOT NULL
),
cohort_sizes AS (
    SELECT
        cohort_quarter,
        COUNT(*) as cohort_size
    FROM cohorts
    GROUP BY cohort_quarter
),
cohort_retention AS (
    SELECT
        c.cohort_quarter,
        c.activity_quarter,
        COUNT(DISTINCT c.show_id) as active_titles,
        cs.cohort_size,
        ROUND(COUNT(DISTINCT c.show_id) * 100.0 / cs.cohort_size, 2) as retention_pct
    FROM cohorts c
    JOIN cohort_sizes cs ON c.cohort_quarter = cs.cohort_quarter
    WHERE c.activity_quarter >= c.cohort_quarter
    GROUP BY c.cohort_quarter, c.activity_quarter, cs.cohort_size
)
SELECT
    TO_CHAR(cohort_quarter, 'YYYY-Q') as cohort,
    TO_CHAR(activity_quarter, 'YYYY-Q') as period,
    active_titles,
    cohort_size,
    retention_pct
FROM cohort_retention
WHERE cohort_quarter >= '2020-01-01'
ORDER BY cohort_quarter, activity_quarter;

-- 10. Composite content score (popularity proxy)
WITH content_metrics AS (
    SELECT
        show_id,
        title,
        type,
        release_year,
        -- Recency score (newer = higher)
        CASE
            WHEN release_year >= 2020 THEN 1.0
            WHEN release_year >= 2015 THEN 0.8
            WHEN release_year >= 2010 THEN 0.6
            WHEN release_year >= 2000 THEN 0.4
            ELSE 0.2
        END as recency_score,
        -- Genre popularity score
        (SELECT AVG(genre_pop) FROM (
            SELECT COUNT(*) as genre_pop
            FROM netflix_titles nt2,
            LATERAL unnest(string_to_array(nt2.listed_in, ', ')) as g
            WHERE nt2.listed_in IS NOT NULL
            AND TRIM(g) IN (SELECT TRIM(genre) FROM unnest(string_to_array(nt.listed_in, ', ')) as genre)
            GROUP BY TRIM(g)
        ) sub) as genre_score,
        -- Country diversity score
        CASE
            WHEN country IS NULL THEN 0
            ELSE LEAST(array_length(string_to_array(country, ', '), 1) * 0.1, 1.0)
        END as country_diversity_score,
        -- Cast size score
        CASE
            WHEN cast IS NULL THEN 0
            ELSE LEAST(array_length(string_to_array(cast, ', '), 1) * 0.05, 1.0)
        END as cast_score
    FROM netflix_titles nt
    WHERE listed_in IS NOT NULL
)
SELECT
    title,
    type,
    release_year,
    ROUND((recency_score * 0.3 + COALESCE(genre_score, 0) * 0.4 + country_diversity_score * 0.2 + cast_score * 0.1) * 100, 1) as content_score
FROM content_metrics
ORDER BY content_score DESC
LIMIT 50;