-- ============================================================
-- B2B Growth Funnel Analytics - Analytical Views
-- ============================================================
-- Purpose: Reusable views that denormalize and aggregate data
--          for common analytical queries
-- Views:
--   1. vw_lead_funnel_summary: Per-lead funnel progression
--   2. vw_monthly_acquisition_performance: Monthly KPIs
-- ============================================================

USE growth_analytics;


-- ============================================================
-- VIEW: Lead Funnel Summary
-- ============================================================
-- One row per lead with complete funnel journey details:
--   - All stage dates (Lead, MQL, SQL, Customer, Lost)
--   - Binary flags for stage achievement
--   - Velocity metrics (days between stages)
--   - Final status and revenue
-- 
-- Use this view as the foundation for most funnel analyses
-- ============================================================

CREATE OR REPLACE VIEW vw_lead_funnel_summary AS
WITH stage_dates AS (
    -- Pivot funnel events to get the date each lead reached each stage
    SELECT
        lead_id,
        MAX(CASE WHEN stage = 'Lead'     THEN stage_date END) AS lead_date,
        MAX(CASE WHEN stage = 'MQL'      THEN stage_date END) AS mql_date,
        MAX(CASE WHEN stage = 'SQL'      THEN stage_date END) AS sql_date,
        MAX(CASE WHEN stage = 'Customer' THEN stage_date END) AS customer_date,
        MAX(CASE WHEN stage = 'Lost'     THEN stage_date END) AS lost_date,
        
        -- Sum revenue from Customer stage events
        SUM(CASE WHEN stage = 'Customer' THEN revenue ELSE 0 END) AS revenue
    FROM 
        fact_funnel_event
    GROUP BY 
        lead_id
)
SELECT
    -- Lead identifiers
    l.lead_id,
    l.created_date AS acquisition_date,
    
    -- Campaign and channel attributes
    c.channel,
    c.campaign_name,
    
    -- Firmographic attributes
    l.region,
    l.company_size,
    l.industry,
    
    -- Cost metrics
    l.acquisition_cost,
    
    -- Stage dates
    s.lead_date,
    s.mql_date,
    s.sql_date,
    s.customer_date,
    s.lost_date,
    
    -- Stage achievement flags (for easy counting)
    CASE WHEN s.mql_date      IS NOT NULL THEN 1 ELSE 0 END AS became_mql,
    CASE WHEN s.sql_date      IS NOT NULL THEN 1 ELSE 0 END AS became_sql,
    CASE WHEN s.customer_date IS NOT NULL THEN 1 ELSE 0 END AS became_customer,
    
    -- Final funnel outcome
    CASE
        WHEN s.customer_date IS NOT NULL THEN 'Customer'
        WHEN s.lost_date     IS NOT NULL THEN 'Lost'
        ELSE 'Open'
    END AS final_status,
    
    -- Velocity metrics: days between stages
    CASE 
        WHEN s.mql_date IS NOT NULL
        THEN DATEDIFF(s.mql_date, l.created_date) 
    END AS days_to_mql,
    
    CASE 
        WHEN s.mql_date IS NOT NULL AND s.sql_date IS NOT NULL
        THEN DATEDIFF(s.sql_date, s.mql_date) 
    END AS days_mql_to_sql,
    
    CASE 
        WHEN s.sql_date IS NOT NULL AND s.customer_date IS NOT NULL
        THEN DATEDIFF(s.customer_date, s.sql_date) 
    END AS days_sql_to_customer,
    
    CASE 
        WHEN s.customer_date IS NOT NULL
        THEN DATEDIFF(s.customer_date, l.created_date) 
    END AS days_to_customer,
    
    -- Revenue (0 if lead never became customer)
    COALESCE(s.revenue, 0) AS revenue
FROM 
    fact_lead_acquisition l
    JOIN dim_campaign c ON l.campaign_id = c.campaign_id
    LEFT JOIN stage_dates s ON l.lead_id = s.lead_id;


-- ============================================================
-- VIEW: Monthly Acquisition Performance
-- ============================================================
-- Aggregates funnel metrics by acquisition month:
--   - Volume: leads, MQLs, SQLs, customers
--   - Financial: acquisition spend, revenue
--   - Efficiency: conversion rates, CAC, ROAS
--
-- Use for time-series trend analysis
-- ============================================================

CREATE OR REPLACE VIEW vw_monthly_acquisition_performance AS
SELECT
    -- Normalize to first day of month
    CAST(DATE_FORMAT(acquisition_date, '%Y-%m-01') AS DATE) AS acquisition_month,
    
    -- Volume metrics
    COUNT(*)              AS leads,
    SUM(became_mql)       AS mqls,
    SUM(became_sql)       AS sqls,
    SUM(became_customer)  AS customers,
    
    -- Financial metrics
    ROUND(SUM(acquisition_cost), 2) AS acquisition_spend,
    ROUND(SUM(revenue), 2)          AS revenue,
    
    -- Efficiency metrics
    ROUND(
        100.0 * SUM(became_customer) / NULLIF(COUNT(*), 0), 
        2
    ) AS lead_to_customer_rate_pct,
    
    -- Customer Acquisition Cost
    ROUND(
        SUM(acquisition_cost) / NULLIF(SUM(became_customer), 0), 
        2
    ) AS cac,
    
    -- Return on Ad Spend
    ROUND(
        SUM(revenue) / NULLIF(SUM(acquisition_cost), 0), 
        2
    ) AS roas
FROM 
    vw_lead_funnel_summary
GROUP BY 
    CAST(DATE_FORMAT(acquisition_date, '%Y-%m-01') AS DATE);
