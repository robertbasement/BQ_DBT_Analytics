#!/bin/bash
set -e

echo "dbt target: ${DBT_TARGET:-dev}"
echo "dbt args: $@"

dbt deps --profiles-dir .
dbt build --profiles-dir . --target "${DBT_TARGET:-dev}" "$@"