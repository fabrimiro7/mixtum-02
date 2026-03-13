from django.urls import path
from .headless_wrapper import (
    HeadlessLoginWrapperView,
    HeadlessRefreshWrapperView,
    HeadlessSignupWrapperView,
)

urlpatterns = [
    path("login/", HeadlessLoginWrapperView.as_view(), name="headless-login"),
    path("refresh/", HeadlessRefreshWrapperView.as_view(), name="headless-refresh"),
    path("signup/", HeadlessSignupWrapperView.as_view(), name="headless-signup"),
]
