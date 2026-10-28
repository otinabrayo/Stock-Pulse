from django.urls import path
from .views import (
    SalesCSVUploadView,
    IngestionRunListView,
    IngestionRunDetailView,
    SaleRecordListView,
    MonthlyComparisonAPIView,
)
from .analytics_views import (
    daily_sales_api,
    product_performance_api,
    sales_summary_api,
)
from .health_views import pipeline_health


urlpatterns = [
    path(
        "ingestions/",
        IngestionRunListView.as_view(),
        name="ingestion-list",
    ),
    path(
        "ingestions/upload/",
        SalesCSVUploadView.as_view(),
        name="ingestion-upload",
    ),
    path(
        "ingestions/<uuid:id>/",
        IngestionRunDetailView.as_view(),
        name="ingestion-detail",
    ),
    path("analytics/summary/", sales_summary_api, name="sales-summary"),
    path("analytics/daily-sales/", daily_sales_api, name="daily-sales"),
    path("analytics/products/", product_performance_api, name="product-performance",),
    path("sales/", SaleRecordListView.as_view(), name="sales-list",),
    path("analytics/monthly-comparison/", MonthlyComparisonAPIView.as_view(), name="monthly-comparison",),
    path("health/pipeline/", pipeline_health, name="pipeline-health",),
]
