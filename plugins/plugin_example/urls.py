from django.urls import path
from . import views

app_name = "plugin_example"

urlpatterns = [
    path(
        "examples/",
        views.ExampleModelListView.as_view(),
        name="example-list",
    ),
    path(
        "examples/<int:pk>/",
        views.ExampleModelDetailView.as_view(),
        name="example-detail",
    ),
]
