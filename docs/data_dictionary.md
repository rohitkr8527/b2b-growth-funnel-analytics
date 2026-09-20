# Data Dictionary

## leads.csv

| Column | Description |
|---|---|
| lead_id | Unique identifier for each lead |
| created_date | Date the lead entered the acquisition funnel |
| channel | Marketing acquisition channel |
| campaign | Marketing campaign associated with the lead |
| region | Geographic region of the lead |
| company_size | Customer company-size segment |
| industry | Customer industry |
| acquisition_cost | Marketing acquisition cost associated with the lead |

## lead_stage_events.csv

| Column | Description |
|---|---|
| lead_id | Lead associated with the event |
| stage | Funnel stage reached by the lead |
| stage_date | Date the stage event occurred |
| revenue | Revenue recorded when a lead becomes a customer |

## Funnel Stages

Expected progression:

Lead → MQL → SQL → Customer

A lead may instead transition to:

Lost

## Funnel Definitions

Lead:
Initial acquired prospect.

MQL:
Marketing Qualified Lead.

SQL:
Sales Qualified Lead.

Customer:
Successfully converted lead.

Lost:
Lead that did not convert.