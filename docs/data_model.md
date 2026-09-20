# MySQL Data Model

## Database

`growth_analytics`

## Tables

### `dim_campaign`

One row per unique marketing campaign and acquisition channel.

| Column | Type | Description |
|---|---|---|
| campaign_id | INT | Surrogate primary key |
| campaign_name | VARCHAR(100) | Campaign name |
| channel | VARCHAR(50) | Acquisition channel |

---

### `fact_lead_acquisition`

One row per acquired lead.

| Column | Type | Description |
|---|---|---|
| lead_id | VARCHAR(20) | Unique lead identifier |
| created_date | DATE | Lead acquisition date |
| campaign_id | INT | Foreign key to `dim_campaign` |
| region | VARCHAR(50) | Lead region |
| company_size | VARCHAR(50) | Company-size segment |
| industry | VARCHAR(100) | Lead industry |
| acquisition_cost | DECIMAL(10,2) | Acquisition cost for the lead |

---

### `fact_funnel_event`

One row per funnel-stage event.

| Column | Type | Description |
|---|---|---|
| event_id | VARCHAR(20) | Unique event identifier |
| lead_id | VARCHAR(20) | Foreign key to `fact_lead_acquisition` |
| stage | VARCHAR(20) | Lead, MQL, SQL, Customer or Lost |
| stage_date | DATE | Date the stage was reached |
| revenue | DECIMAL(12,2) | Revenue recorded on Customer events |

## Relationships

```text
dim_campaign
     1
     |
     | campaign_id
     |
     *
fact_lead_acquisition
     1
     |
     | lead_id
     |
     *
fact_funnel_event
```

This structure preserves the raw business grain while keeping the model simple enough for SQL analysis and Power BI.
