from django.urls import path

from apps.tracking.views import (
    RiderTrackingView,
    RiderWalletView,
    TrackingHealthView,
    WithdrawalRequestView,
)


urlpatterns = [
    path("health/", TrackingHealthView.as_view(), name="tracking-health"),
    path("rider/", RiderTrackingView.as_view(), name="rider-tracking"),
    path("wallet/", RiderWalletView.as_view(), name="rider-wallet"),
    path("withdrawals/", WithdrawalRequestView.as_view(), name="withdrawals"),
]
