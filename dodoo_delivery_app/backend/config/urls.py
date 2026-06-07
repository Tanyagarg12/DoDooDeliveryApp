from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def api_home(request):
    return JsonResponse(
        {
            "message": "DoDoo Delivery backend is running.",
            "endpoints": {
                "admin": "/admin/",
                "rider_signup": "/api/riders/signup/",
                "rider_login": "/api/riders/login/",
                "send_otp": "/api/riders/send-otp/",
                "verify_otp": "/api/riders/verify-otp/",
                "orders": "/api/orders/",
                "tracking_health": "/api/tracking/health/",
            },
        }
    )


urlpatterns = [
    path("", api_home, name="api-home"),
    path("admin/", admin.site.urls),
    path("api/riders/", include("apps.riders.urls")),
    path("api/orders/", include("apps.orders.urls")),
    path("api/tracking/", include("apps.tracking.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
