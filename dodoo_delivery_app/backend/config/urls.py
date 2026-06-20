from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health_check(request):
    """Lightweight DB + server liveness probe used by the Flutter test-connection button."""
    from django.db import connection
    try:
        with connection.cursor() as cur:
            cur.execute("SELECT 1")
        db_ok = True
    except Exception:
        db_ok = False
    return JsonResponse({"status": "ok" if db_ok else "db_error", "db": "connected" if db_ok else "error"})


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
    path("api/health/", health_check, name="health-check"),
    path("admin/", admin.site.urls),
    path("api/riders/", include("apps.riders.urls")),
    path("api/orders/", include("apps.orders.urls")),
    path("api/tracking/", include("apps.tracking.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
