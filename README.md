# BQ_DBT_Analytics

BQ_DBT_Analytics is a modern analytics engineering project built on Google BigQuery and dbt.

The project transforms raw Taiwanese stock market data, monthly revenue disclosures, and financial statements into clean, backtest-ready analytical datasets.

## Tech Stack

- Google BigQuery
- dbt Core
- Cloud Run Jobs
- Cloud Functions
- Google Cloud Storage (Data Lake)
- Pub/Sub

## Data Pipeline

Raw Data Sources
¡õ
Cloud Functions (Scrapers)
¡õ
Google Cloud Storage
¡õ
BigQuery Raw Tables
¡õ
dbt Transformations
¡õ
Analytics Marts
¡õ
Quantitative Research & Backtesting

## Key Datasets

- Adjusted Daily Prices
- Technical Indicators
- Monthly Revenue Features
- Financial Statement Features
- Revenue/Financial Release Alignment
- Master Backtesting Dataset

## Goals

- Build a reliable stock analytics warehouse
- Support quantitative factor research
- Provide reproducible transformations through dbt
- Enable automated cloud-native data pipelines on GCP