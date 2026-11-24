# Analysis Methodology

## Data Source
- **Dataset**: Netflix Movies and TV Shows (Kaggle)
- **Rows**: 82,000+ titles
- **Columns**: 12 attributes (show_id, type, title, director, cast, country, date_added, release_year, rating, duration, listed_in, description)
- **Time Period**: Content released 1925-2021, added to Netflix 2008-2021

## Data Preparation

### Cleaning Steps
1. **Missing Value Handling**
   - `director`: 15% missing → kept as NULL for "Unknown"
   - `cast`: 10% missing → kept as NULL
   - `country`: 5% missing → kept as NULL
   - `date_added`: 2% missing → excluded from temporal addition analysis
   - `rating`: 3% missing → categorized as "Unrated"
   - `duration`: <1% missing → excluded from duration analysis

2. **Data Type Normalization**
   - `date_added`: Parsed from 'Month DD, YYYY' to DATE type
   - `duration`: Split into numeric value + unit (min/Season)
   - `listed_in`: Split comma-separated genres into arrays
   - `country`: Split comma-separated countries into arrays
   - `director`: Split comma-separated directors into arrays
   - `cast`: Split comma-separated actors into arrays

3. **Rating Normalization**
   Mapped various ratings to standard categories:
   - Children/Family: G, TV-G, TV-Y, TV-Y7
   - Parental Guidance: PG, TV-PG
   - Teens/Young Adults: PG-13, TV-14
   - Mature/Adult: R, NC-17, TV-MA
   - Unrated: NR, UR, NOT RATED, UNRATED

## Analytical Approach

### 1. Exploratory Analysis
- Basic counts, distributions, and summary statistics
- Data quality assessment
- Identification of key dimensions for deep-dive

### 2. Genre Analysis
- **Explosion Technique**: Used `LATERAL unnest(string_to_array())` to normalize comma-separated genres
- **Metrics**: Title count, percentage of catalog, rank, type breakdown
- **Advanced**: Genre co-occurrence matrix, genre diversity per title, genre trends over time

### 3. Temporal Analysis
- **Release Year**: Original content production year
- **Date Added**: When content joined Netflix catalog
- **Lag Analysis**: Difference between release and addition
- **Growth Rates**: Year-over-year percentage changes
- **Seasonality**: Monthly addition patterns

### 4. Geographic Analysis
- **Country Explosion**: Normalized multi-country productions
- **Regional Grouping**: Mapped countries to 6 regions
- **Co-production Analysis**: Titles with multiple production countries
- **Country-Genre Matrix**: Genre preferences by country

### 5. Rating Analysis
- **Distribution**: Overall and by content type
- **Trends**: Rating category evolution over time
- **Genre-Rating Mapping**: Content maturity by genre
- **Country-Rating**: Regional content maturity differences

### 6. Duration Analysis
- **Movies**: Runtime in minutes (percentiles, buckets, trends)
- **TV Shows**: Season count (distribution, trends, long-running shows)
- **Correlations**: Duration vs rating, duration vs genre

### 7. Creator Analysis
- **Director/ Actor Explosion**: Normalized comma-separated credits
- **Productivity**: Title counts, year spans, genre specialization
- **Collaborations**: Director-actor pair frequency
- **International**: Non-US director representation

### 8. Advanced Analytics
- **Window Functions**: Running totals, moving averages, rankings
- **Percentiles**: Duration distributions (P10, P25, P50, P75, P90, P95, P99)
- **Trend Detection**: Linear approximation for genre momentum
- **Similarity Analysis**: Jaccard index for genre overlap
- **Market Basket**: Genre combination lift/confidence
- **Anomaly Detection**: Z-score outliers for duration
- **Content Gap**: Country vs global genre representation
- **Projection**: Simple linear trend for content pipeline

## SQL Techniques Demonstrated

| Technique | Usage |
|-----------|-------|
| CTEs (WITH) | All complex queries |
| Window Functions | ROW_NUMBER, RANK, LAG, LEAD, SUM OVER, AVG OVER |
| Percentile Functions | PERCENTILE_CONT for distributions |
| Lateral Joins | Array explosion (unnest + string_to_array) |
| Array Functions | array_length, generate_subscripts |
| Materialized Views | Pre-computed analytics for dashboards |
| Pivot/Unpivot | Rating by type matrices |
| Conditional Aggregation | FILTER clauses for multi-metric queries |
| Recursive CTEs | Genre pair generation |
| Date Functions | EXTRACT, DATE_TRUNC, TO_CHAR |

## Performance Optimizations

1. **Indexes**: Created on filter columns (type, release_year, rating, country) and composite indexes
2. **Materialized Views**: Pre-aggregated for dashboard queries
3. **Partitioning Strategy**: Tables could be partitioned by release_year for larger datasets
4. **Query Patterns**: Avoided SELECT *, used specific columns

## Limitations & Assumptions

1. **Dataset Snapshots**: Data represents Netflix catalog at time of dataset creation (2021)
2. **Genre Subjectivity**: Netflix's genre tags may not align with standard taxonomies
3. **Country Attribution**: Production country ≠ availability country
4. **Duration Approximation**: TV show seasons converted to minutes (×60) for comparison
5. **Missing Data**: Analysis excludes NULL values where noted
6. **Rating Changes**: Content ratings may have changed since original release

## Reproducibility

All analysis is contained in version-controlled SQL files that can be run sequentially:
```bash
./scripts/setup_database.sh      # One-time setup
./scripts/run_analysis.sh        # Run all queries
python scripts/export_results.py # Format for visualization
jupyter notebook notebooks/netflix_visualization.ipynb
```