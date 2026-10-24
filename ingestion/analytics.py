from decimal import Decimal
from django.db.models import (
    DecimalField,
    ExpressionWrapper,
    F,
    Sum,
)
from django.db.models.functions import TruncDate
from .models import SaleRecord


MONEY_FIELD = DecimalField(
    max_digits=20,
    decimal_places=2,
)


def sales_metrics(queryset=None):
    """
    Return headline metrics for validated sales records.
    """
    if queryset is None:
        queryset = SaleRecord.objects.all()

    revenue_expression = ExpressionWrapper(
        F("quantity") * F("unit_price"),
        output_field=MONEY_FIELD,
    )

    cost_expression = ExpressionWrapper(
        F("quantity") * F("unit_cost"),
        output_field=MONEY_FIELD,
    )

    totals = queryset.aggregate(
        total_units=Sum("quantity"),
        total_revenue=Sum(revenue_expression),
        total_cost=Sum(cost_expression),
    )

    revenue = totals["total_revenue"] or Decimal("0.00")
    cost = totals["total_cost"] or Decimal("0.00")

    return {
        "transactions": queryset.values(
            "transaction_id"
        ).distinct().count(),
        "sales_lines": queryset.count(),
        "units_sold": totals["total_units"] or 0,
        "revenue": revenue,
        "cost": cost,
        "gross_profit": revenue - cost,
    }


def daily_sales():
    revenue_expression = ExpressionWrapper(
        F("quantity") * F("unit_price"),
        output_field=MONEY_FIELD,
    )

    cost_expression = ExpressionWrapper(
        F("quantity") * F("unit_cost"),
        output_field=MONEY_FIELD,
    )

    return list(
        SaleRecord.objects
        .annotate(sale_date=TruncDate("sold_at"))
        .values("sale_date")
        .annotate(
            units_sold=Sum("quantity"),
            revenue=Sum(revenue_expression),
            cost=Sum(cost_expression),
        )
        .order_by("sale_date")
    )


def product_performance():
    revenue_expression = ExpressionWrapper(
        F("quantity") * F("unit_price"),
        output_field=MONEY_FIELD,
    )

    return list(
        SaleRecord.objects
        .values("sku", "product__name", "product__category")
        .annotate(
            units_sold=Sum("quantity"),
            revenue=Sum(revenue_expression),
        )
        .order_by("-revenue")
    )
