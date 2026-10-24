from django.urls import path
from .views import (
    SalesCSVUploadView,
    IngestionRunListView,
    IngestionRunDetailView,
)
from .analytics_views import (
    SalesSummaryView,
    DailySalesView,
    ProductPerformanceView,
)


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
    path(
        "analytics/summary/",
        SalesSummaryView.as_view(),
        name="analytics-summary",
    ),
    path(
        "analytics/daily-sales/",
        DailySalesView.as_view(),
        name="analytics-daily-sales",
    ),
    path(
        "analytics/products/",
        ProductPerformanceView.as_view(),
        name="analytics-products",
    ),
]
