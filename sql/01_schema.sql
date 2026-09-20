-- ============================================================
-- B2B Growth Funnel Analytics
-- Stage 3 - MySQL Schema
-- ============================================================

CREATE TABLE IF NOT EXISTS dim_campaign (
    campaign_id INT PRIMARY KEY,
    campaign_name VARCHAR(100) NOT NULL,
    channel VARCHAR(50) NOT NULL,
    CONSTRAINT uq_campaign UNIQUE (campaign_name, channel)
);

CREATE TABLE IF NOT EXISTS fact_lead_acquisition (
    lead_id VARCHAR(20) PRIMARY KEY,
    created_date DATE NOT NULL,
    campaign_id INT NOT NULL,
    region VARCHAR(50) NOT NULL,
    company_size VARCHAR(50) NOT NULL,
    industry VARCHAR(100) NOT NULL,
    acquisition_cost DECIMAL(10, 2) NOT NULL,

    CONSTRAINT fk_lead_campaign
        FOREIGN KEY (campaign_id)
        REFERENCES dim_campaign(campaign_id),

    CONSTRAINT chk_acquisition_cost
        CHECK (acquisition_cost >= 0)
);

CREATE TABLE IF NOT EXISTS fact_funnel_event (
    event_id VARCHAR(20) PRIMARY KEY,
    lead_id VARCHAR(20) NOT NULL,
    stage VARCHAR(20) NOT NULL,
    stage_date DATE NOT NULL,
    revenue DECIMAL(12, 2) NOT NULL DEFAULT 0,

    CONSTRAINT fk_event_lead
        FOREIGN KEY (lead_id)
        REFERENCES fact_lead_acquisition(lead_id),

    CONSTRAINT chk_stage
        CHECK (stage IN ('Lead', 'MQL', 'SQL', 'Customer', 'Lost')),

    CONSTRAINT chk_revenue
        CHECK (revenue >= 0)
);

CREATE INDEX idx_lead_created_date
    ON fact_lead_acquisition(created_date);

CREATE INDEX idx_lead_campaign
    ON fact_lead_acquisition(campaign_id);

CREATE INDEX idx_lead_region
    ON fact_lead_acquisition(region);

CREATE INDEX idx_lead_company_size
    ON fact_lead_acquisition(company_size);

CREATE INDEX idx_lead_industry
    ON fact_lead_acquisition(industry);

CREATE INDEX idx_event_lead
    ON fact_funnel_event(lead_id);

CREATE INDEX idx_event_stage
    ON fact_funnel_event(stage);

CREATE INDEX idx_event_stage_date
    ON fact_funnel_event(stage_date);
