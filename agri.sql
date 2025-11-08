

# Year-wise Trend of Rice Production Across States (Top 3)
WITH state_ranked AS (
    SELECT 
        year,
        state_name,
        SUM(rice_production_1000tons) AS total_rice_production,
        RANK() OVER (PARTITION BY year ORDER BY SUM(rice_production_1000tons) DESC) AS state_rank
    FROM agriculturedate.agri_reports
    GROUP BY year, state_name
)
SELECT 
    year,
    state_name,
    total_rice_production
FROM state_ranked
WHERE state_rank <= 3
ORDER BY year, total_rice_production DESC;


# Top 5 Districts by Wheat Yield Increase Over the Last 5 Years
WITH district_yield AS (
    SELECT 
        dist_name,
        year,
        AVG(wheat_yield_kg_per_ha) AS avg_wheat_yield
    FROM agriculturedate.agri_reports
    GROUP BY dist_name, year
),
district_change AS (
    SELECT 
        dist_name,
        MAX(CASE WHEN year = (SELECT MAX(year) FROM agriculturedate.agri_reports) THEN avg_wheat_yield END) AS latest_yield,
        MAX(CASE WHEN year = (SELECT MAX(year)-4 FROM agriculturedate.agri_reports) THEN avg_wheat_yield END) AS yield_5_years_ago
    FROM district_yield
    GROUP BY dist_name
)
SELECT 
    dist_name,
    (latest_yield - yield_5_years_ago) AS yield_increase_kg_per_ha
FROM district_change
WHERE latest_yield IS NOT NULL AND yield_5_years_ago IS NOT NULL
ORDER BY yield_increase_kg_per_ha DESC
LIMIT 5;


# States with the Highest Growth in Oilseed Production (5-Year Growth Rate)
WITH state_oilseed AS (
    SELECT 
        state_name,
        year,
        SUM(oilseeds_production_1000tons) AS total_oilseed_production
    FROM agriculturedate.agri_reports
    GROUP BY state_name, year
),
state_growth AS (
    SELECT 
        state_name,
        MAX(CASE WHEN year = (SELECT MAX(year) FROM agriculturedate.agri_reports) THEN total_oilseed_production END) AS latest_production,
        MAX(CASE WHEN year = (SELECT MAX(year)-4 FROM agriculturedate.agri_reports) THEN total_oilseed_production END) AS production_5_years_ago
    FROM state_oilseed
    GROUP BY state_name
)
SELECT 
    state_name,
    production_5_years_ago,
    latest_production,
    ROUND(
        ((latest_production - production_5_years_ago) / production_5_years_ago) * 100, 
        2
    ) AS growth_rate_percent
FROM state_growth
WHERE latest_production IS NOT NULL 
  AND production_5_years_ago IS NOT NULL
ORDER BY growth_rate_percent DESC;



# District-wise Correlation Between Area and Production for Major Crops (Rice, Wheat, and Maize)

WITH crop_data AS (
    SELECT 
        dist_name,
        'Rice' AS crop,
        rice_area_1000ha AS area,
        rice_production_1000tons AS production
    FROM agriculturedate.agri_reports
    UNION ALL
    SELECT 
        dist_name,
        'Wheat' AS crop,
        wheat_area_1000ha AS area,
        wheat_production_1000tons AS production
    FROM agriculturedate.agri_reports
    UNION ALL
    SELECT 
        dist_name,
        'Maize' AS crop,
        maize_area_1000ha AS area,
        maize_production_1000tons AS production
    FROM agriculturedate.agri_reports
),
stats AS (
    SELECT
        dist_name,
        crop,
        COUNT(*) AS n,
        AVG(area) AS mean_area,
        AVG(production) AS mean_production,
        SUM(area * production) AS sum_xy,
        SUM(area * area) AS sum_xx,
        SUM(production * production) AS sum_yy
    FROM crop_data
    GROUP BY dist_name, crop
)
SELECT
    dist_name,
    crop,
    ROUND(
        (sum_xy - n * mean_area * mean_production)
        /
        (SQRT(sum_xx - n * mean_area * mean_area) * SQRT(sum_yy - n * mean_production * mean_production)),
        4
    ) AS correlation_area_production
FROM stats
ORDER BY dist_name, crop;

# Yearly Production Growth of Cotton in Top 5 Cotton Producing States

WITH total_cotton AS (
    SELECT 
        state_name,
        SUM(cotton_production_1000tons) AS total_cotton_production
    FROM agriculturedate.agri_reports
    GROUP BY state_name
    ORDER BY total_cotton_production DESC
    LIMIT 5
),

yearly_cotton AS (
    SELECT 
        a.year,
        a.state_name,
        SUM(a.cotton_production_1000tons) AS yearly_cotton_production
    FROM agriculturedate.agri_reports a
    INNER JOIN total_cotton t 
        ON a.state_name = t.state_name
    GROUP BY a.year, a.state_name
),

growth AS (
    SELECT 
        state_name,
        year,
        yearly_cotton_production,
        LAG(yearly_cotton_production) OVER (
            PARTITION BY state_name 
            ORDER BY year
        ) AS prev_year_production
    FROM yearly_cotton
)

SELECT 
    state_name,
    year,
    yearly_cotton_production,
    prev_year_production,
    (yearly_cotton_production - prev_year_production) AS production_growth
FROM growth
ORDER BY state_name, year;



# Annual Average Maize Yield Across All States
SELECT 
    year,
    state_name,
    ROUND(AVG(maize_yield_kg_per_ha), 2) AS avg_maize_yield_kg_per_ha
FROM agriculturedate.agri_reports
GROUP BY year, state_name
ORDER BY year, state_name;

# Total Area Cultivated for Oilseeds in Each State

SELECT 
    state_name,
    SUM(oilseeds_area_1000ha) AS total_oilseeds_area_1000ha
FROM agriculturedate.agri_reports
GROUP BY state_name
ORDER BY total_oilseeds_area_1000ha DESC;

# Districts with the Highest Rice Yield
SELECT 
    dist_name,
    state_name,
    ROUND(AVG(rice_yield_kg_per_ha), 2) AS avg_rice_yield_kg_per_ha
FROM agriculturedate.agri_reports
GROUP BY dist_name, state_name
ORDER BY avg_rice_yield_kg_per_ha DESC
LIMIT 10;

# Compare the Production of Wheat and Rice for the Top 5 States Over 10 Years

WITH latest_years AS (
    SELECT DISTINCT year
    FROM agriculturedate.agri_reports
    ORDER BY year DESC
    LIMIT 10
),
state_totals AS (
    SELECT 
        state_name,
        SUM(rice_production_1000tons + wheat_production_1000tons) AS total_combined
    FROM agriculturedate.agri_reports
    WHERE year IN (SELECT year FROM latest_years)
    GROUP BY state_name
    ORDER BY total_combined DESC
    LIMIT 5
),
yearly_data AS (
    SELECT 
        a.year,
        a.state_name,
        SUM(a.rice_production_1000tons) AS rice_production_1000tons,
        SUM(a.wheat_production_1000tons) AS wheat_production_1000tons
    FROM agriculturedate.agri_reports a
    INNER JOIN state_totals s ON a.state_name = s.state_name
    WHERE a.year IN (SELECT year FROM latest_years)
    GROUP BY a.year, a.state_name
)
SELECT 
    year,
    state_name,
    rice_production_1000tons,
    wheat_production_1000tons
FROM yearly_data
ORDER BY state_name, year;




 # States with the Highest Growth in Oilseed Production (5-Year Growth Rate)


WITH yearly_prod AS (
    SELECT
        state_name,
        year,
        SUM(oilseeds_production_1000tons) AS oilseed_prod
    FROM agriculturedate.agri_reports
    GROUP BY state_name, year
),

growth_calc AS (
    SELECT
        state_name,
        MIN(year) AS start_year,
        MAX(year) AS end_year,
        FIRST_VALUE(oilseed_prod) OVER (PARTITION BY state_name ORDER BY year) AS start_prod,
        FIRST_VALUE(oilseed_prod) OVER (PARTITION BY state_name ORDER BY year DESC) AS end_prod
    FROM yearly_prod
    GROUP BY state_name, year
)

SELECT 
    state_name,
    start_prod,
    end_prod,
    (end_prod - start_prod) AS growth_absolute,
    ROUND(( (end_prod - start_prod) / NULLIF(start_prod,0) ) * 100, 2) AS growth_percent
FROM growth_calc
GROUP BY state_name, start_prod, end_prod
ORDER BY growth_percent DESC;
