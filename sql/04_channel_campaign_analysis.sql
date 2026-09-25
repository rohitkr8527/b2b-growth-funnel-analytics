-- ============================================================
-- B2B Growth Funnel Analytics - Channel & Campaign Analysis
-- ============================================================
-- Purpose: Evaluate marketing channel and campaign performance
--          with focus on ROI, efficiency, and ranking
-- 
-- Questions answered:
--   Q1. Channel economics (CAC, ROAS, revenue per lead)
--   Q2. Campaign performance across all metrics
--   Q3. Campaign rankings within each channel
--   Q4. Campaign performance profiles (2x2 matrix)
--   Q5. Revenue concentration by channel
--   Q6. Channel performance vs. portfolio average
-- ============================================================

USE growth_analytics;


-- ============================================================
-- Q1. Channel Economics - High-Level Performance
-- ============================================================
-- Evaluates each marketing channel's financial performance
-- Key metrics: CAC (Customer Acquisition Cost), ROAS (Return on Ad Spend)
-- ============================================================

WITH channel_metrics AS (
    -- Aggregate metrics by channel
    SELECT
        channel,
        COUNT(*)                 AS leads,
        SUM(became_customer)     AS customers,
        SUM(acquisition_cost)    AS acquisition_spend,
        SUM(revenue)             AS revenue
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        channel
)
SELECT
    channel,
    leads,
    customers,
    
    -- Financial totals
    ROUND(acquisition_spend, 2) AS acquisition_spend,
    ROUND(revenue, 2)           AS revenue,
    
    -- Efficiency metrics
    ROUND(100.0 * customers / NULLIF(leads, 0), 2) AS conversion_rate_pct,
    
    -- Customer Acquisition Cost (spend per customer)
    ROUND(acquisition_spend / NULLIF(customers, 0), 2) AS cac,
    
    -- Return on Ad Spend (revenue per dollar spent)
    ROUND(revenue / NULLIF(acquisition_spend, 0), 2) AS roas,
    
    -- Revenue per lead (blended efficiency metric)
    ROUND(revenue / NULLIF(leads, 0), 2) AS revenue_per_lead
FROM 
    channel_metrics
ORDER BY 
    roas DESC;


-- ============================================================
-- Q2. Campaign Performance - Detailed Metrics
-- ============================================================
-- Comprehensive view of each campaign's performance
-- Includes conversion, financial, and velocity metrics
-- ============================================================

WITH campaign_metrics AS (
    -- Aggregate metrics by channel and campaign
    SELECT
        channel,
        campaign_name,
        COUNT(*)                 AS leads,
        SUM(became_customer)     AS customers,
        SUM(acquisition_cost)    AS acquisition_spend,
        SUM(revenue)             AS revenue,
        
        -- Average conversion time for successful customers
        AVG(CASE 
            WHEN became_customer = 1 
            THEN days_to_customer 
        END) AS avg_days_to_customer
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        channel, 
        campaign_name
)
SELECT
    channel,
    campaign_name,
    leads,
    customers,
    
    -- Financial metrics
    ROUND(acquisition_spend, 2)         AS acquisition_spend,
    ROUND(revenue, 2)                   AS revenue,
    
    -- Performance metrics
    ROUND(100.0 * customers / NULLIF(leads, 0), 2) AS conversion_rate_pct,
    ROUND(acquisition_spend / NULLIF(customers, 0), 2) AS cac,
    ROUND(revenue / NULLIF(acquisition_spend, 0), 2) AS roas,
    
    -- Velocity metric
    ROUND(avg_days_to_customer, 2)      AS avg_days_to_customer
FROM 
    campaign_metrics
ORDER BY 
    revenue DESC;


-- ============================================================
-- Q3. Rank Campaigns Within Each Channel
-- ============================================================
-- Identifies top performers within each channel by:
--   - Revenue (total revenue generated)
--   - ROAS (efficiency of spend)
-- ============================================================

WITH campaign_metrics AS (
    -- Calculate campaign metrics
    SELECT
        channel,
        campaign_name,
        COUNT(*)              AS leads,
        SUM(became_customer)  AS customers,
        SUM(revenue)          AS revenue,
        SUM(acquisition_cost) AS acquisition_spend
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        channel, 
        campaign_name
),
ranked AS (
    -- Rank campaigns within each channel
    SELECT 
        *,
        -- Rank by total revenue (descending)
        DENSE_RANK() OVER (
            PARTITION BY channel 
            ORDER BY revenue DESC
        ) AS revenue_rank,
        
        -- Rank by ROAS (descending)
        DENSE_RANK() OVER (
            PARTITION BY channel 
            ORDER BY revenue / NULLIF(acquisition_spend, 0) DESC
        ) AS roas_rank
    FROM 
        campaign_metrics
)
SELECT
    channel,
    campaign_name,
    leads,
    customers,
    ROUND(revenue, 2)           AS revenue,
    ROUND(acquisition_spend, 2) AS acquisition_spend,
    ROUND(revenue / NULLIF(acquisition_spend, 0), 2) AS roas,
    revenue_rank,
    roas_rank
FROM 
    ranked
ORDER BY 
    channel, 
    revenue_rank, 
    campaign_name;


-- ============================================================
-- Q4. Campaign Performance Profile (2x2 Matrix)
-- ============================================================
-- Segments campaigns into quadrants based on:
--   - Conversion rate (above/below average)
--   - ROAS (above/below average)
-- Useful for portfolio management decisions
-- ============================================================

WITH campaign_metrics AS (
    -- Calculate base metrics
    SELECT
        channel,
        campaign_name,
        COUNT(*)              AS leads,
        SUM(became_customer)  AS customers,
        SUM(acquisition_cost) AS spend,
        SUM(revenue)          AS revenue
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        channel, 
        campaign_name
),
metrics AS (
    -- Calculate derived metrics
    SELECT 
        *,
        100.0 * customers / NULLIF(leads, 0)   AS conversion_rate,
        revenue / NULLIF(spend, 0)             AS roas
    FROM 
        campaign_metrics
),
benchmarks AS (
    -- Calculate portfolio averages
    SELECT 
        AVG(conversion_rate) AS avg_conversion_rate,
        AVG(roas)            AS avg_roas
    FROM 
        metrics
)
SELECT
    m.channel,
    m.campaign_name,
    m.leads,
    m.customers,
    ROUND(m.conversion_rate, 2) AS conversion_rate_pct,
    ROUND(m.roas, 2)            AS roas,
    
    -- Classify into quadrants
    CASE
        WHEN m.conversion_rate >= b.avg_conversion_rate 
         AND m.roas >= b.avg_roas
            THEN 'High Conversion / High ROAS'
            
        WHEN m.conversion_rate >= b.avg_conversion_rate 
         AND m.roas < b.avg_roas
            THEN 'High Conversion / Low ROAS'
            
        WHEN m.conversion_rate < b.avg_conversion_rate 
         AND m.roas >= b.avg_roas
            THEN 'Low Conversion / High ROAS'
            
        ELSE 'Low Conversion / Low ROAS'
    END AS performance_profile
FROM 
    metrics m
    CROSS JOIN benchmarks b
ORDER BY 
    performance_profile, 
    m.roas DESC;


-- ============================================================
-- Q5. Revenue Concentration by Channel
-- ============================================================
-- Shows how revenue is distributed across channels
-- Identifies concentration risk or diversification
-- ============================================================

WITH channel_revenue AS (
    -- Calculate total revenue per channel
    SELECT 
        channel, 
        SUM(revenue) AS revenue
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        channel
),
total AS (
    -- Calculate portfolio total revenue
    SELECT 
        SUM(revenue) AS total_revenue 
    FROM 
        channel_revenue
)
SELECT
    c.channel,
    ROUND(c.revenue, 2) AS revenue,
    
    -- Percentage of total revenue from this channel
    ROUND(
        100.0 * c.revenue / NULLIF(t.total_revenue, 0), 
        2
    ) AS revenue_share_pct
FROM 
    channel_revenue c
    CROSS JOIN total t
ORDER BY 
    revenue DESC;


-- ============================================================
-- Q6. Channel Performance vs. Portfolio Average
-- ============================================================
-- Compares each channel to the overall portfolio average
-- Shows relative over/under-performance
-- ============================================================

WITH channel_metrics AS (
    -- Calculate channel-level metrics
    SELECT
        channel,
        COUNT(*)              AS leads,
        SUM(became_customer)  AS customers,
        SUM(acquisition_cost) AS spend,
        SUM(revenue)          AS revenue
    FROM 
        vw_lead_funnel_summary
    GROUP BY 
        channel
),
scored AS (
    -- Calculate efficiency ratios
    SELECT 
        *,
        100.0 * customers / NULLIF(leads, 0) AS conversion_rate,
        spend / NULLIF(customers, 0)         AS cac,
        revenue / NULLIF(spend, 0)           AS roas
    FROM 
        channel_metrics
)
SELECT
    channel,
    leads,
    customers,
    ROUND(conversion_rate, 2) AS conversion_rate_pct,
    ROUND(cac, 2)             AS cac,
    ROUND(roas, 2)            AS roas,
    
    -- Variance from portfolio average (in percentage points)
    ROUND(
        conversion_rate - AVG(conversion_rate) OVER (), 
        2
    ) AS conversion_vs_avg_pp,
    
    -- Variance from portfolio average ROAS
    ROUND(
        roas - AVG(roas) OVER (), 
        2
    ) AS roas_vs_avg
FROM 
    scored
ORDER BY 
    roas DESC;
