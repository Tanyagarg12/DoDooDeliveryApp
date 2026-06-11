import math

from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.riders.models import Rider
from apps.riders.serializers import RiderSerializer, RiderSignupSerializer

MAX_ORDER_DISTANCE_KM = 15


def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


class RiderSignupView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        existing_rider = Rider.objects.filter(phone=request.data.get("phone")).first()
        if existing_rider:
            return Response(
                {
                    "message": "Rider already exists. Please verify OTP or log in.",
                    "rider_id": str(existing_rider.id),
                    "phone": existing_rider.phone,
                },
                status=status.HTTP_200_OK,
            )

        serializer = RiderSignupSerializer(data=request.data)
        if serializer.is_valid():
            rider = serializer.save()
            return Response(
                {
                    "message": "Signup successful. Please verify OTP.",
                    "rider_id": str(rider.id),
                    "phone": rider.phone,
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RiderSendOtpView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get("phone")
        if not phone:
            return Response({"error": "Phone is required"}, status=status.HTTP_400_BAD_REQUEST)

        if not Rider.objects.filter(phone=phone).exists():
            return Response({"error": "Rider not found"}, status=status.HTTP_404_NOT_FOUND)

        return Response(
            {
                "message": "OTP sent successfully.",
                "phone": phone,
                "dev_otp": "123456",
            }
        )


class RiderVerifyOtpView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get("phone")
        otp = request.data.get("otp")

        if otp != "123456":
            return Response({"error": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            rider = Rider.objects.get(phone=phone)
        except Rider.DoesNotExist:
            return Response({"error": "Rider not found"}, status=status.HTTP_404_NOT_FOUND)

        rider.is_verified = True
        rider.save(update_fields=["is_verified", "last_active"])
        refresh = RefreshToken.for_user(rider)
        return Response(
            {
                "message": "OTP verified successfully.",
                "access_token": str(refresh.access_token),
                "token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "rider": RiderSerializer(rider).data,
            }
        )


class RiderLoginView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get("phone")
        password = request.data.get("password")

        try:
            rider = Rider.objects.get(phone=phone)
        except Rider.DoesNotExist:
            return Response({"error": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)

        if not rider.check_password(password):
            return Response({"error": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)

        refresh = RefreshToken.for_user(rider)
        return Response(
            {
                "access_token": str(refresh.access_token),
                "token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "rider": RiderSerializer(rider).data,
            }
        )


class RiderProfileView(APIView):
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get(self, request):
        return Response(RiderSerializer(request.user, context={"request": request}).data)

    def put(self, request):
        serializer = RiderSerializer(request.user, data=request.data, partial=True, context={"request": request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RiderStatusView(APIView):
    def post(self, request):
        status_value = request.data.get("status")
        valid_statuses = {choice[0] for choice in Rider.RIDER_STATUS_CHOICES}
        if status_value not in valid_statuses:
            return Response({"error": "Invalid status"}, status=status.HTTP_400_BAD_REQUEST)

        request.user.current_status = status_value
        request.user.save(update_fields=["current_status", "last_active"])
        return Response({"status": status_value, "message": "Status updated"})


class ActiveRidersView(APIView):
    def get(self, request):
        from apps.orders.models import Order

        riders = Rider.objects.filter(current_status__in=["online", "busy"]).order_by("current_status", "first_name")
        data = []
        for rider in riders:
            if rider.current_status == "busy":
                active_order = Order.objects.filter(
                    assigned_rider=rider,
                    status__in=["accepted", "picked_up", "in_transit", "reached"],
                ).values("to_latitude", "to_longitude", "distance_in_km").first()
                if active_order:
                    if rider.current_latitude is not None and rider.current_longitude is not None:
                        dist = haversine_km(
                            rider.current_latitude, rider.current_longitude,
                            active_order["to_latitude"], active_order["to_longitude"],
                        )
                        if dist >= MAX_ORDER_DISTANCE_KM:
                            continue
                    elif active_order["distance_in_km"] >= MAX_ORDER_DISTANCE_KM:
                        continue

            tracking = getattr(rider, "current_tracking", None)
            data.append(
                {
                    **RiderSerializer(rider, context={"request": request}).data,
                    "tracking": {
                        "latitude": tracking.latitude,
                        "longitude": tracking.longitude,
                        "order_id": str(tracking.order_id) if tracking.order_id else None,
                        "is_tracking": tracking.is_tracking,
                        "updated_at": tracking.updated_at,
                    }
                    if tracking
                    else None,
                }
            )
        return Response(data)
