from rest_framework.response import Response
from rest_framework.views import APIView
from .analytics import (
    daily_sales,
    product_performance,
    sales_metrics,
)


class SalesSummaryView(APIView):
    def get(self, request):
        return Response(sales_metrics())


class DailySalesView(APIView):
    def get(self, request):
        rows = daily_sales()

        return Response([
            {
                "date": row["sale_date"],
                "units_sold": row["units_sold"] or 0,
                "revenue": row["revenue"] or 0,
                "cost": row["cost"] or 0,
                "gross_profit": (
                    (row["revenue"] or 0)
                    - (row["cost"] or 0)
                ),
            }
            for row in rows
        ])


class ProductPerformanceView(APIView):
    def get(self, request):
        rows = product_performance()

        return Response([
            {
                "sku": row["sku"],
                "name": row["product__name"],
                "category": row["product__category"],
                "units_sold": row["units_sold"] or 0,
                "revenue": row["revenue"] or 0,
            }
            for row in rows
        ])
