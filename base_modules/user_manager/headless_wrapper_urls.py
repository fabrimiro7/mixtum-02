from django.urls import path
from .headless_wrapper import HeadlessLoginWrapperView, HeadlessRefreshWrapperView

urlpatterns = [
    path("login/", HeadlessLoginWrapperView.as_view(), name="headless-login"),
    path("refresh/", HeadlessRefreshWrapperView.as_view(), name="headless-refresh"),
]
