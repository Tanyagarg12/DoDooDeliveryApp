from django.urls import path

from apps.riders.views import (
    RiderLoginView,
    ActiveRidersView,
    RiderProfileView,
    RiderSendOtpView,
    RiderSignupView,
    RiderStatusView,
    RiderVerifyOtpView,
)


urlpatterns = [
    path("signup/", RiderSignupView.as_view(), name="signup"),
    path("login/", RiderLoginView.as_view(), name="login"),
    path("send-otp/", RiderSendOtpView.as_view(), name="send-otp"),
    path("verify-otp/", RiderVerifyOtpView.as_view(), name="verify-otp"),
    path("profile/", RiderProfileView.as_view(), name="profile"),
    path("status/", RiderStatusView.as_view(), name="status"),
    path("active/", ActiveRidersView.as_view(), name="active-riders"),
]
