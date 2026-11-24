# Database Schema Documentation

## Table: `netflix_titles`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `show_id` | VARCHAR(10) | PRIMARY KEY | Unique identifier (e.g., 's1', 's2') |
| `type` | VARCHAR(20) | NOT NULL | 'Movie' or 'TV Show' |
| `title` | VARCHAR(500) | NOT NULL | Content title |
| `director` | VARCHAR(500) | NULL | Director name(s) |
| `cast` | TEXT | NULL | Main cast members |
| `country` | VARCHAR(500) | NULL | Production country(ies) |
| `date_added` | DATE | NULL | Date added to Netflix |
| `release_year` | INTEGER | NOT NULL | Year of original release |
| `rating` | VARCHAR(20) | NULL | Age rating (TV-MA, PG-13, etc.) |
| `duration` | VARCHAR(50) | NULL | Runtime (min) or seasons |
| `listed_in` | VARCHAR(500) | NULL | Genre(s), comma-separated |
| `description` | TEXT | NOT NULL | Content description |

## Indexes Created

```sql
-- For filtering by type
CREATE INDEX idx_netflix_type ON netflix_titles(type);

-- For temporal queries
CREATE INDEX idx_netflix_release_year ON netflix_titles(release_year);
CREATE INDEX idx_netflix_date_added ON netflix_titles(date_added);

-- For rating analysis
CREATE INDEX idx_netflix_rating ON netflix_titles(rating);

-- For country analysis
CREATE INDEX idx_netflix_country ON netflix_titles(country);

-- For genre analysis (using GIN on array)
CREATE INDEX idx_netflix_genres_gin ON netflix_titles USING GIN (genres_array);

-- Composite for common query patterns
CREATE INDEX idx_netflix_type_year ON netflix_titles(type, release_year);
CREATE INDEX idx_netflix_type_rating ON netflix_titles(type, rating);
```

## Derived Columns (Computed in Views)

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| `genres_array` | TEXT[] | `listed_in` | Split genres as array |
| `countries_array` | TEXT[] | `country` | Split countries as array |
| `directors_array` | TEXT[] | `director` | Split directors as array |
| `cast_array` | TEXT[] | `cast` | Split cast as array |
| `duration_value` | INTEGER | `duration` | Numeric duration (minutes or seasons) |
| `duration_unit` | VARCHAR(10) | `duration` | 'min' or 'Season(s)' |
| `date_added_year` | INTEGER | `date_added` | Year extracted from date_added |
| `date_added_month` | INTEGER | `date_added` | Month extracted from date_added |
| `age_rating_category` | VARCHAR(20) | `rating` | Normalized rating category |

## Data Quality Notes

- **Missing Values**: ~15% missing `director`, ~10% missing `cast`, ~5% missing `country`
- **Date Format**: `date_added` in 'Month DD, YYYY' format (e.g., 'September 25, 2021')
- **Duration Format**: Movies: '90 min', TV Shows: '3 Seasons'
- **Genres**: Comma-separated, 1-10 genres per title
- **Countries**: Comma-separated, 1-5 countries per title