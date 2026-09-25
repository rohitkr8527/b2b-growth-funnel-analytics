-- ============================================================
-- B2B Growth Funnel Analytics - Funnel Analysis
-- ============================================================
-- Purpose: Queries to analyze funnel conversion rates,
--          drop-off points, and sales cycle velocity
-- 
-- Questions answered:
--   Q1. Overall funnel volume and conversion rates
--   Q2. Stage-by-stage drop-off analysis
--   Q3. Funnel conversion by channel
--   Q4. Overall funnel velocity (days between stages)
--   Q5. Sales-cycle speed by channel
--   Q6. Slowest converting successful segments
-- ============================================================

USE growth_analytics;


-- ============================================================
-- Q1. Overall Funnel Volume and Conversion Rates
-- ============================================================
-- Shows the complete funnel with volumes at each stage and
-- conversion rates between consecutive stages
-- ============================================================

WITH funnel AS (
    -- Aggregate all leads and count progression to each stage
    SELECT
        COUNT(*)            AS leads,
        SUM(became_mql)     AS mqls,
        SUM(became_sql)     AS sqls,
        SUM(became_customer) AS customers
    FROM 
        vw_lead_funnel_summary
)
SELECT
    leads,
    mqls,
    sqls,
    customers,
    
    -- Conversion rates between each stage
    ROUND(100.0 * mqls      / NULLIF(leads, 0), 2) AS lead_to_mql_rate_pct,
    ROUND(100.0 * sqls      / NULLIF(mqls, 0),  2) AS mql_to_sql_rate_pct,
    ROUND(100.0 * customers / NULLIF(sqls, 0),  2) AS sql_to_customer_rate_pct,
    
    -- Overall end-to-end conversion rate
    ROUND(100.0 * customers / NULLIF(leads, 0), 2) AS lead_to_customer_rate_pct
FROM 
    funnel;


-- ============================================================
-- Q2. Stage-by-Stage Drop-Off Analysis
-- ============================================================
-- Identifies where leads are dropping out of the funnel
-- and quantifies the drop-off at each transition
-- ============================================================

WITH funnel AS (
    -- Get total counts at each stage
    SELECT 
        COUNT(*)            AS leads,
        SUM(became_mql)     AS mqls,
        SUM(became_sql)     AS sqls,
        SUM(became_customer) AS customers
    FROM 
        vw_lead_funnel_summary
),
stages AS (
    -- Create one row per stage transition
    SELECT 
        1 AS stage_order, 
        'Lead -> MQL' AS transition,
        leads AS starting_leads, 
        mqls AS progressing_leads 
    FROM funnel
    
    UNION ALL
    
    SELECT 
        2, 
        'MQL -> SQL', 
        mqls, 
        sqls 
    FROM funnel
    
    UNION ALL
    
    SELECT 
        3, 
        'SQL -> Customer', 
        sqls, 
        customers 
    FROM funnel
)
SELECT
    transition,
    starting_leads,
    progressing_leads,
    
    -- Calculate drop-off counts and rates
    starting_leads - progressing_leads AS drop_off_count,
    ROUND(
        100.0 * (starting_leads - progressing_leads) / NULLIF(starting_leads, 0), 
        2
    ) AS drop_off_rate_pct
FROM 
    stages
ORDER BY 
    stage_order;


-- ============================================================
-- Q3. Funnel Conversion by Channel
-- ============================================================
-- Compares funnel performance across marketing channels
-- to identify which channels produce the highest quality leads
-- ============================================================

SELECT
    channel,
    
    -- Volume at each stage
    COUNT(*)            AS leads,
    SUM(became_mql)     AS mqls,
    SUM(became_sql)     AS sqls,
    SUM(became_customer) AS customers,
    
    -- Stage-by-stage conversion rates
    ROUND(100.0 * SUM(became_mql)      / NULLIF(COUNT(*), 0),          2) AS lead_to_mql_pct,
    ROUND(100.0 * SUM(became_sql)      / NULLIF(SUM(became_mql), 0),  2) AS mql_to_sql_pct,
    ROUND(100.0 * SUM(became_customer) / NULLIF(SUM(became_sql), 0),  2) AS sql_to_customer_pct,
    
    -- Overall conversion rate
    ROUND(100.0 * SUM(became_customer) / NULLIF(COUNT(*), 0), 2) AS overall_conversion_pct
FROM 
    vw_lead_funnel_summary
GROUP BY 
    channel
ORDER BY 
    overall_conversion_pct DESC;


-- ============================================================
-- Q4. Funnel Velocity - Average Days Between Stages
-- ============================================================
-- Measures how quickly leads progress through the funnel
-- Shows average time spent at each stage
-- ============================================================

SELECT
    ROUND(AVG(days_to_mql),          2) AS avg_days_to_mql,
    ROUND(AVG(days_mql_to_sql),      2) AS avg_days_mql_to_sql,
    ROUND(AVG(days_sql_to_customer), 2) AS avg_days_sql_to_customer,
    
    -- Total time from lead to customer
    ROUND(AVG(days_to_customer),     2) AS avg_days_to_customer
FROM 
    vw_lead_funnel_summary;


-- ============================================================
-- Q5. Sales-Cycle Speed by Channel
-- ============================================================
-- Compares conversion velocity across channels
-- Only includes successful conversions (became_customer = 1)
-- ============================================================

SELECT
    channel,
    COUNT(*) AS customers,
    
    -- Average, fastest, and slowest conversion times
    ROUND(AVG(days_to_customer), 2) AS avg_days_to_customer,
    MIN(days_to_customer)           AS fastest_conversion_days,
    MAX(days_to_customer)           AS slowest_conversion_days
FROM 
    vw_lead_funnel_summary
WHERE 
    became_customer = 1
GROUP BY 
    channel
ORDER BY 
    avg_days_to_customer;


-- ============================================================
-- Q6. Slowest Converting Successful Segments
-- ============================================================
-- Identifies industry + company size combinations that
-- convert successfully but take the longest time
-- Useful for understanding complex sales cycles
-- ============================================================

SELECT
    industry,
    company_size,
    COUNT(*) AS customers,
    
    -- Conversion time and revenue metrics
    ROUND(AVG(days_to_customer), 2) AS avg_days_to_customer,
    ROUND(AVG(revenue), 2)          AS avg_customer_revenue
FROM 
    vw_lead_funnel_summary
WHERE 
    became_customer = 1
GROUP BY 
    industry, 
    company_size
HAVING 
    -- Filter out segments with too few conversions
    COUNT(*) >= 2
ORDER BY 
    avg_days_to_customer DESC, 
    customers DESC;
