-- ============================================================
-- B2B Growth Funnel Analytics - Database Schema
-- ============================================================
-- Purpose: Core schema for tracking B2B lead acquisition and 
--          funnel progression through marketing stages
-- Tables:
--   1. dim_campaign: Marketing campaign dimension
--   2. fact_lead_acquisition: Lead acquisition facts
--   3. fact_funnel_event: Funnel stage progression events
-- ============================================================


-- ============================================================
-- DIMENSION TABLE: Campaign
-- ============================================================
-- Stores marketing campaign and channel information
-- Each campaign belongs to a specific marketing channel
-- ============================================================

CREATE TABLE IF NOT EXISTS dim_campaign (
    campaign_id   INT PRIMARY KEY,
    campaign_name VARCHAR(100) NOT NULL,
    channel       VARCHAR(50) NOT NULL,
    
    -- Ensure unique campaign names within each channel
    CONSTRAINT uq_campaign UNIQUE (campaign_name, channel)
);


-- ============================================================
-- FACT TABLE: Lead Acquisition
-- ============================================================
-- Captures initial lead acquisition with firmographic data
-- and acquisition cost tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS fact_lead_acquisition (
    lead_id          VARCHAR(20) PRIMARY KEY,
    created_date     DATE NOT NULL,
    campaign_id      INT NOT NULL,
    
    -- Firmographic attributes
    region           VARCHAR(50) NOT NULL,
    company_size     VARCHAR(50) NOT NULL,
    industry         VARCHAR(100) NOT NULL,
    
    -- Cost tracking
    acquisition_cost DECIMAL(10, 2) NOT NULL,

    -- Foreign key to campaign dimension
    CONSTRAINT fk_lead_campaign
        FOREIGN KEY (campaign_id)
        REFERENCES dim_campaign(campaign_id),

    -- Ensure acquisition cost is non-negative
    CONSTRAINT chk_acquisition_cost
        CHECK (acquisition_cost >= 0)
);


-- ============================================================
-- FACT TABLE: Funnel Events
-- ============================================================
-- Tracks lead progression through funnel stages:
--   - Lead: Initial acquisition
--   - MQL: Marketing Qualified Lead
--   - SQL: Sales Qualified Lead
--   - Customer: Successful conversion
--   - Lost: Dropped out of funnel
-- ============================================================

CREATE TABLE IF NOT EXISTS fact_funnel_event (
    event_id   VARCHAR(20) PRIMARY KEY,
    lead_id    VARCHAR(20) NOT NULL,
    stage      VARCHAR(20) NOT NULL,
    stage_date DATE NOT NULL,
    
    -- Revenue generated (only applicable for Customer stage)
    revenue    DECIMAL(12, 2) NOT NULL DEFAULT 0,

    -- Foreign key to lead acquisition
    CONSTRAINT fk_event_lead
        FOREIGN KEY (lead_id)
        REFERENCES fact_lead_acquisition(lead_id),

    -- Restrict to valid funnel stages
    CONSTRAINT chk_stage
        CHECK (stage IN ('Lead', 'MQL', 'SQL', 'Customer', 'Lost')),

    -- Ensure revenue is non-negative
    CONSTRAINT chk_revenue
        CHECK (revenue >= 0)
);


-- ============================================================
-- INDEXES: Lead Acquisition Table
-- ============================================================
-- Optimize queries by common filter and grouping columns
-- ============================================================

-- Time-based analysis (monthly/quarterly trends)
CREATE INDEX idx_lead_created_date
    ON fact_lead_acquisition(created_date);

-- Campaign performance analysis
CREATE INDEX idx_lead_campaign
    ON fact_lead_acquisition(campaign_id);

-- Geographic segmentation
CREATE INDEX idx_lead_region
    ON fact_lead_acquisition(region);

-- Company size segmentation
CREATE INDEX idx_lead_company_size
    ON fact_lead_acquisition(company_size);

-- Industry vertical analysis
CREATE INDEX idx_lead_industry
    ON fact_lead_acquisition(industry);


-- ============================================================
-- INDEXES: Funnel Event Table
-- ============================================================
-- Optimize joins and stage-based filtering
-- ============================================================

-- Join back to lead acquisition data
CREATE INDEX idx_event_lead
    ON fact_funnel_event(lead_id);

-- Filter by funnel stage
CREATE INDEX idx_event_stage
    ON fact_funnel_event(stage);

-- Time-based event analysis
CREATE INDEX idx_event_stage_date
    ON fact_funnel_event(stage_date);
