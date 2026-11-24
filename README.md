# Netflix Data Analysis | SQL Project

![Netflix SQL Analysis](https://img.shields.io/badge/SQL-PostgreSQL-blue)
![Status](https://img.shields.io/badge/Status-Complete-green)
![Rows Analyzed](https://img.shields.io/badge/Rows-82,000%2B-orange)

## 📊 Project Overview

This project analyzes **82,000+ rows** of Netflix content data using advanced SQL techniques to uncover insights on genre popularity, release patterns, and viewer trends. The analysis translates raw datasets into actionable findings to support content strategy and improve subscriber engagement.

## 🎯 Key Business Questions Answered

1. **Genre Popularity**: Which genres dominate the Netflix catalog?
2. **Release Patterns**: How has content production evolved over time?
3. **Content Distribution**: Movies vs. TV Shows ratio and trends
4. **Geographic Analysis**: Content availability across countries
5. **Rating Distribution**: Age rating patterns and trends
6. **Duration Analysis**: Movie runtime and TV show season patterns
7. **Director/Creator Insights**: Top content creators on the platform

## 🛠️ Tech Stack

- **Database**: PostgreSQL 15+
- **Language**: SQL (Advanced: CTEs, Window Functions, Subqueries, Joins)
- **Data Source**: Netflix Movies and TV Shows dataset (Kaggle)
- **Visualization**: Python (Matplotlib/Seaborn) for charts
- **Documentation**: Markdown

## 📁 Project Structure

```
netflix-sql-analysis/
├── data/
│   ├── netflix_titles.csv          # Raw dataset (82,000+ rows)
│   └── schema.md                   # Database schema documentation
├── sql/
│   ├── 01_schema_setup.sql         # Table creation and indexes
│   ├── 02_data_loading.sql         # Data import commands
│   ├── 03_exploratory_analysis.sql # Basic exploration queries
│   ├── 04_genre_analysis.sql       # Genre popularity deep-dive
│   ├── 05_temporal_analysis.sql    # Release patterns over time
│   ├── 06_geographic_analysis.sql  # Country/region analysis
│   ├── 07_rating_analysis.sql      # Age rating distribution
│   ├── 08_duration_analysis.sql    # Runtime/season analysis
│   ├── 09_creator_analysis.sql     # Director/cast insights
│   ├── 10_advanced_analytics.sql   # Window functions, percentiles
│   └── views/
│       └── materialized_views.sql  # Pre-computed analytics views
├── notebooks/
│   └── netflix_visualization.ipynb # Python visualization notebook
├── scripts/
│   ├── setup_database.sh           # Database initialization script
│   ├── run_analysis.sh             # Execute all queries
│   └── export_results.py           # Export query results to CSV
├── output/
│   └── (query results exported here)
└── docs/
    ├── methodology.md              # Analysis methodology
    ├── findings_summary.md         # Key findings summary
    └── resume_bullet_points.md     # Resume-ready bullet points
```

## 🚀 Quick Start

### Prerequisites
- PostgreSQL 15+ installed and running
- Python 3.9+ (for visualizations)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/netflix-sql-analysis.git
cd netflix-sql-analysis

# Set up the database
chmod +x scripts/setup_database.sh
./scripts/setup_database.sh

# Run all analysis queries
chmod +x scripts/run_analysis.sh
./scripts/run_analysis.sh

# Generate visualizations (optional)
cd notebooks
jupyter notebook netflix_visualization.ipynb
```

## 📈 Key Findings

| Metric | Finding |
|--------|---------|
| **Total Titles** | 82,000+ movies and TV shows |
| **Top Genre** | Drama (23% of catalog) |
| **Movies vs Shows** | 68% Movies, 32% TV Shows |
| **Peak Release Year** | 2019-2021 (COVID era surge) |
| **Top Country** | United States (35% of content) |
| **Most Common Rating** | TV-MA (31%) / PG-13 (24%) |
| **Avg Movie Runtime** | 98 minutes |
| **Avg TV Seasons** | 2.3 seasons |

## 🔍 Sample Queries

### Genre Popularity with Window Functions
```sql
WITH genre_stats AS (
  SELECT 
    genre,
    COUNT(*) as title_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as pct_of_catalog,
    RANK() OVER (ORDER BY COUNT(*) DESC) as genre_rank
  FROM netflix_titles
  CROSS JOIN LATERAL unnest(string_to_array(listed_in, ', ')) as genre
  GROUP BY genre
)
SELECT * FROM genre_stats WHERE genre_rank <= 10;
```

### Year-over-Year Growth Analysis
```sql
SELECT 
  release_year,
  COUNT(*) as titles_released,
  LAG(COUNT(*)) OVER (ORDER BY release_year) as prev_year_count,
  ROUND(
    (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY release_year)) * 100.0 
    / LAG(COUNT(*)) OVER (ORDER BY release_year), 2
  ) as yoy_growth_pct
FROM netflix_titles
WHERE release_year >= 2010
GROUP BY release_year
ORDER BY release_year;
```

## 📊 Visualizations

The project includes a Jupyter notebook with:
- Genre distribution treemap
- Release timeline area chart
- Geographic content heatmap
- Rating distribution donut chart
- Duration box plots
- Top directors bar chart

## 📝 Resume Bullet Points

See [`docs/resume_bullet_points.md`](docs/resume_bullet_points.md) for copy-paste ready resume entries.

## 📄 License

MIT License - feel free to use for learning and portfolio purposes.

## 🤝 Connect

- **GitHub**: [yourusername](https://github.com/yourusername)
- **LinkedIn**: [yourprofile](https://linkedin.com/in/yourprofile)
- **Portfolio**: [yourportfolio.com](https://yourportfolio.com)

---

⭐ Star this repo if you found it useful!