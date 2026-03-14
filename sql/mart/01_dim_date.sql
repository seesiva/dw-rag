-- Dimension: Date
-- 1 row per calendar day from 2020 to 2030 (supports analysis across years)

CREATE SCHEMA IF NOT EXISTS mart;

DROP TABLE IF EXISTS mart.dim_date CASCADE;
CREATE TABLE mart.dim_date AS
WITH date_series AS (
    SELECT
        d::DATE AS full_date
    FROM generate_series(
        '2020-01-01'::DATE,
        '2030-12-31'::DATE,
        '1 day'::INTERVAL
    ) AS t(d)
)
SELECT
    (TO_CHAR(full_date, 'YYYYMMDD'))::INT AS date_id,
    full_date,
    EXTRACT(YEAR FROM full_date)::INT AS year,
    EXTRACT(QUARTER FROM full_date)::INT AS quarter,
    EXTRACT(MONTH FROM full_date)::INT AS month,
    TO_CHAR(full_date, 'MMMM') AS month_name,
    EXTRACT(WEEK FROM full_date)::INT AS week_of_year,
    EXTRACT(DOW FROM full_date)::INT AS day_of_week,
    TO_CHAR(full_date, 'FMDay') AS day_name,
    EXTRACT(DAY FROM full_date)::INT AS day_of_month,
    CASE
        WHEN EXTRACT(DOW FROM full_date) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend,
    CASE
        WHEN EXTRACT(MONTH FROM full_date) < 4 THEN EXTRACT(YEAR FROM full_date) - 1
        ELSE EXTRACT(YEAR FROM full_date)
    END::VARCHAR(4) AS fiscal_year
FROM date_series;

ALTER TABLE mart.dim_date ADD PRIMARY KEY (date_id);
CREATE INDEX idx_dim_date_full_date ON mart.dim_date(full_date);
