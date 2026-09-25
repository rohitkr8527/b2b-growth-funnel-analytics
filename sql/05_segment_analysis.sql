-- ============================================================
-- B2B Growth Funnel Analytics - Segment Analysis
-- ============================================================
-- Purpose: Analyze lead performance by firmographic segments
--          (industry, company size, region)
-- 
-- Questions answered:
--   Q1. Industry performance and economics
--   Q2. Company-size tier performance
--   Q3. Regional performance comparison
--   Q4. Industry + company-size opportunity matrix
--   Q5. Industry rankings within company-size segments
--   Q6. Segment quality index (diagnostic scoring)
-- ============================================================

USE growth_analytics;


-- ============================================================
-- Q1. Industry Performance
-- ============================================================
-- Evaluates which industry verticals perform best
-- Includes conversion, financial, and velocity metrics
-- ============================================================

SELECT
    industry,
    
    -- Volume metrics
    COUNT(*)             AS leads,
    SUM(became_customer) AS customers,
    
    -- Financial metrics
    ROUND(SUM(revenue), 2)          AS revenue,
    ROUND(SUM(acquisition_cost), 2) AS acquisition_spend,
    
    -- Efficiency metrics
    ROUND(100.0 * SUM(became_customer) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct,
    
    -- Customer Acquisition Cost
    ROUND(SUM(acquisition_cost) / NULLIF(SUM(became_customer), 0), 2) AS cac,
    
    -- Return on Ad Spend
    ROUND(SUM(revenue) / NULLIF(SUM(acquisition_cost), 0), 2) AS roas,
    
    -- Velocity metric (for successful conversions only)
    ROUND(AVG(CASE 
        WHEN became_customer = 1 
        THEN days_to_customer 
    END), 2) AS avg_days_to_customer
FROM 
    vw_lead_funnel_summary
GROUP BY 
    industry
ORDER BY 
    revenue DESC;


-- ============================================================
-- Q2. Company-Size Tier Performance
-- ============================================================
-- Compares performance across company size segments
-- Useful for understanding ideal customer profile
-- ============================================================

SELECT
    company_size,
    
    -- Volume metrics
    COUNT(*)             AS leads,
    SUM(became_customer) AS customers,
    
    -- Financial metrics
    ROUND(SUM(revenue), 2) AS revenue,
    
    -- Efficiency metrics
    ROUND(100.0 * SUM(became_customer) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct,
    
    -- Customer Acquisition Cost
    ROUND(SUM(acquisition_cost) / NULLIF(SUM(became_customer), 0), 2) AS cac,
    
    -- Return on Ad Spend
    ROUND(SUM(revenue) / NULLIF(SUM(acquisition_cost), 0), 2) AS roas,
    
    -- Average customer value
    ROUND(AVG(CASE 
        WHEN became_customer = 1 
        THEN revenue 
    END), 2) AS avg_customer_revenue
FROM 
    vw_lead_funnel_summary
GROUP BY 
    company_size
ORDER BY 
    revenue DESC;


-- ============================================================
-- Q3. Regional Performance
-- ============================================================
-- Compares geographic market performance
-- Identifies high-potential and underperforming regions
-- ============================================================

SELECT
    region,
    
    -- Volume metrics
    COUNT(*)             AS leads,
    SUM(became_customer) AS customers,
    
    -- Financial metrics
    ROUND(SUM(revenue), 2) AS revenue,
    
    -- Efficiency metrics
    ROUND(100.0 * SUM(became_customer) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct,
    
    -- Customer Acquisition Cost
    ROUND(SUM(acquisition_cost) / NULLIF(SUM(became_customer), 0), 2) AS cac,
    
    -- Return on Ad Spend
    ROUND(SUM(revenue) / NULLIF(SUM(acquisition_cost), 0), 2) AS roas
FROM 
    vw_lead_funnel_summary
GROUP BY 
    region
ORDER BY 
    revenue DESC;


-- ============================================================
-- Q4. Industry + Company-Size Opportunity Matrix
-- ============================================================
-- Cross-segment analysis to identify the most valuable
-- combinations of industry and company size
-- ============================================================

WITH segment_metrics AS (
    -- Calculate metrics for each industry × company_size combination
    SELECT
        industry,
        company_size,
        COUNT(*)              AS leads,
        SUM(became_customer)  AS customers,
        SUM(revenue)          AS revenue,
        SUM(acquisition_cost) AS spend
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        industry, 
        company_size
)
SELECT
    industry,
    company_size,
    leads,
    customers,
    
    -- Financial metrics
    ROUND(revenue, 2) AS revenue,
    
    -- Efficiency metrics
    ROUND(100.0 * customers / NULLIF(leads, 0), 2) AS conversion_rate_pct,
    
    -- Customer Acquisition Cost
    ROUND(spend / NULLIF(customers, 0), 2) AS cac,
    
    -- Return on Ad Spend
    ROUND(revenue / NULLIF(spend, 0), 2) AS roas
FROM 
    segment_metrics
ORDER BY 
    revenue DESC, 
    conversion_rate_pct DESC;


-- ============================================================
-- Q5. Rank Industries Within Company-Size Segments
-- ============================================================
-- For each company size tier, identifies which industries
-- generate the most revenue
-- ============================================================

WITH metrics AS (
    -- Calculate metrics for each segment
    SELECT
        company_size,
        industry,
        COUNT(*)             AS leads,
        SUM(became_customer) AS customers,
        SUM(revenue)         AS revenue
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        company_size, 
        industry
),
ranked AS (
    -- Rank industries within each company size
    SELECT 
        *,
        DENSE_RANK() OVER (
            PARTITION BY company_size
            ORDER BY revenue DESC
        ) AS revenue_rank
    FROM 
        metrics
)
SELECT
    company_size,
    industry,
    leads,
    customers,
    ROUND(revenue, 2) AS revenue,
    revenue_rank
FROM 
    ranked
ORDER BY 
    company_size, 
    revenue_rank, 
    industry;


-- ============================================================
-- Q6. Segment Quality Index (Diagnostic Scoring)
-- ============================================================
-- Creates a composite score for each segment based on:
--   - Conversion rate relative to average
--   - Revenue per lead relative to average
-- Higher scores indicate better-performing segments
-- ============================================================

WITH segment_metrics AS (
    -- Calculate base metrics for each segment
    SELECT
        industry,
        company_size,
        COUNT(*)             AS leads,
        SUM(became_customer) AS customers,
        SUM(revenue)         AS revenue
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        industry, 
        company_size
),
calculated AS (
    -- Calculate derived metrics
    SELECT 
        *,
        100.0 * customers / NULLIF(leads, 0) AS conversion_rate,
        revenue / NULLIF(leads, 0)           AS revenue_per_lead
    FROM 
        segment_metrics
),
benchmarks AS (
    -- Calculate portfolio-wide averages
    SELECT
        AVG(conversion_rate)   AS avg_conversion,
        AVG(revenue_per_lead)  AS avg_revenue_per_lead
    FROM 
        calculated
)
SELECT
    s.industry,
    s.company_size,
    s.leads,
    s.customers,
    ROUND(s.conversion_rate, 2)   AS conversion_rate_pct,
    ROUND(s.revenue_per_lead, 2)  AS revenue_per_lead,
    
    -- Quality index: sum of normalized ratios
    -- Score > 2 indicates above-average on both dimensions
    ROUND(
        (s.conversion_rate / NULLIF(b.avg_conversion, 0))
        + (s.revenue_per_lead / NULLIF(b.avg_revenue_per_lead, 0)),
        2
    ) AS segment_quality_index
FROM 
    calculated s
    CROSS JOIN benchmarks b
ORDER BY 
    segment_quality_index DESC;
