from django.urls import path

from apps.riders.views import (
    CheckPhoneView,
    RiderRegisterView,
    RiderLoginView,
    ActiveRidersView,
    RiderProfileView,
    RiderSendOtpView,
    RiderSignupView,
    RiderStatusView,
    RiderStatusCheckView,
    RiderVerifyOtpView,
)
from apps.riders.admin_views import (
    AdminLoginView,
    AdminRiderListView,
    AdminRiderDetailView,
    AdminRiderActionView,
    AdminRiderApprovalLogsView,
    AdminDashboardStatsView,
)

urlpatterns = [
    # OTP-only auth (new flow)
    path('check-phone/', CheckPhoneView.as_view(), name='check-phone'),
    path('register/', RiderRegisterView.as_view(), name='register'),

    # Shared OTP endpoints
    path('send-otp/', RiderSendOtpView.as_view(), name='send-otp'),
    path('verify-otp/', RiderVerifyOtpView.as_view(), name='verify-otp'),

    # Legacy password-based flow
    path('signup/', RiderSignupView.as_view(), name='signup'),
    path('login/', RiderLoginView.as_view(), name='login'),

    # Authenticated rider endpoints
    path('profile/', RiderProfileView.as_view(), name='profile'),
    path('status/', RiderStatusView.as_view(), name='status'),
    path('active/', ActiveRidersView.as_view(), name='active-riders'),

    # Admin approval workflow
    path('admin/login/', AdminLoginView.as_view(), name='admin-login'),
    path('admin/stats/', AdminDashboardStatsView.as_view(), name='admin-stats'),
    path('admin/riders/', AdminRiderListView.as_view(), name='admin-rider-list'),
    path('admin/riders/<uuid:rider_id>/', AdminRiderDetailView.as_view(), name='admin-rider-detail'),
    path('admin/riders/<uuid:rider_id>/action/', AdminRiderActionView.as_view(), name='admin-rider-action'),
    path('admin/riders/<uuid:rider_id>/logs/', AdminRiderApprovalLogsView.as_view(), name='admin-rider-logs'),
    # Rider status check endpoint (for auto-refresh in Flutter)
    path('me/status/', RiderStatusCheckView.as_view(), name='rider-status-check'),
]
