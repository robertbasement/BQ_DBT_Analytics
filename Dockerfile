FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV DBT_PROFILES_DIR=/app

RUN chmod +x run_dbt.sh

ENTRYPOINT ["./run_dbt.sh"]