import os
import re
from decimal import Decimal
from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET
from django.http import JsonResponse
from django.views.decorators.http import require_GET

from .analytics import sales_metrics, daily_sales, product_performance


def json_safe(value):
    if isinstance(value, Decimal):
        return str(value)
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return value


def serialize_rows(rows):
    return [
        {key: json_safe(value) for key, value in row.items()}
        for row in rows
    ]


def get_marts_schema():
    schema = os.environ.get(
        "DBT_MARTS_SCHEMA",
        "analytics_marts",
    )

    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", schema):
        raise ValueError("Invalid DBT_MARTS_SCHEMA")

    return schema


def query_rows(sql, params=None):
    with connection.cursor() as cursor:
        cursor.execute(sql, params or [])
        columns = [column[0] for column in cursor.description]
        return [
            dict(zip(columns, row))
            for row in cursor.fetchall()
        ]


@require_GET
def daily_sales_api(request):
    rows = serialize_rows(daily_sales())
    rows.reverse()  # Most recent dates first
    return JsonResponse({
        "count": len(rows),
        "results": rows[:365],
    })


@require_GET
def product_performance_api(request):
    rows = serialize_rows(product_performance())
    rows.sort(key=lambda row: Decimal(str(row["revenue"] or 0)),
              reverse=True)
    return JsonResponse({
        "count": len(rows),
        "results": rows[:100],
    })


@require_GET
def sales_summary_api(request):
    return JsonResponse(serialize_rows([sales_metrics()])[0])
