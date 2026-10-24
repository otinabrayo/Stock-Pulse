
from django.urls import path

from .views import (
    SalesCSVUploadView,
    IngestionRunListView,
    IngestionRunDetailView,
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
]
