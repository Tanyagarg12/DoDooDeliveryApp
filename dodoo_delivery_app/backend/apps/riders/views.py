import math
import random

from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.riders.models import Rider
from apps.riders.serializers import RiderRegistrationSerializer, RiderSerializer, RiderSignupSerializer

MAX_ORDER_DISTANCE_KM = 15


def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


# ─── OTP-only auth (new flow) ────────────────────────────────────────────────

class CheckPhoneView(APIView):
    """Check whether a phone number is already registered."""
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get('phone', '').strip()
        if not phone:
            return Response({'error': 'Phone is required'}, status=status.HTTP_400_BAD_REQUEST)

        rider = Rider.objects.filter(phone=phone).first()
        if rider:
            return Response({
                'exists': True,
                'account_status': rider.account_status,
                'rider_id': str(rider.id),
                'phone': phone,
            })
        return Response({'exists': False, 'phone': phone})


class RiderRegisterView(APIView):
    """
    OTP-only registration. Accepts multipart/form-data with document images.
    Sets account_status='pending' and requires admin approval before login.
    """
    permission_classes = []
    authentication_classes = []
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        phone = request.data.get('phone', '').strip()
        if not phone:
            return Response({'error': 'Phone is required'}, status=status.HTTP_400_BAD_REQUEST)

        if Rider.objects.filter(phone=phone).exists():
            return Response(
                {'error': 'Phone already registered. Please login.', 'already_exists': True},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = RiderRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            rider = serializer.save()
            # Pre-generate OTP so it is ready when send-otp is called next
            otp = str(random.randint(100000, 999999))
            rider.current_otp = otp
            rider.save(update_fields=['current_otp'])
            return Response(
                {
                    'message': 'Registration successful. OTP sent to your phone.',
                    'rider_id': str(rider.id),
                    'phone': rider.phone,
                    'dev_otp': otp,
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ─── Shared OTP endpoints ─────────────────────────────────────────────────────

class RiderSendOtpView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get('phone', '').strip()
        if not phone:
            return Response({'error': 'Phone is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            rider = Rider.objects.get(phone=phone)
        except Rider.DoesNotExist:
            return Response({'error': 'Rider not found'}, status=status.HTTP_404_NOT_FOUND)

        # Generate a fresh random 6-digit OTP and persist it on the rider
        otp = str(random.randint(100000, 999999))
        rider.current_otp = otp
        rider.save(update_fields=['current_otp'])

        # In production: send otp via Twilio / MSG91 here instead of returning it
        return Response({
            'message': 'OTP sent successfully.',
            'phone': phone,
            'dev_otp': otp,          # shown on-screen during demo
        })


class RiderVerifyOtpView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get('phone', '').strip()
        otp = request.data.get('otp', '').strip()

        try:
            rider = Rider.objects.get(phone=phone)
        except Rider.DoesNotExist:
            return Response({'error': 'Rider not found'}, status=status.HTTP_404_NOT_FOUND)

        # Verify against the OTP stored on the rider
        stored_otp = rider.current_otp
        if not stored_otp or otp != stored_otp:
            return Response({'error': 'Invalid OTP. Please request a new one.'}, status=status.HTTP_400_BAD_REQUEST)

        rider.is_verified = True
        rider.current_otp = None          # invalidate after single use
        rider.save(update_fields=['is_verified', 'current_otp', 'last_active'])

        refresh = RefreshToken.for_user(rider)
        return Response({
            'message': 'OTP verified successfully.',
            'access_token': str(refresh.access_token),
            'token': str(refresh.access_token),
            'refresh_token': str(refresh),
            'rider': RiderSerializer(rider, context={'request': request}).data,
        })


# ─── Legacy password-based login (kept for backward compatibility) ─────────────

class RiderSignupView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        existing = Rider.objects.filter(phone=request.data.get('phone')).first()
        if existing:
            return Response(
                {
                    'message': 'Rider already exists. Please verify OTP or log in.',
                    'rider_id': str(existing.id),
                    'phone': existing.phone,
                },
                status=status.HTTP_200_OK,
            )
        serializer = RiderSignupSerializer(data=request.data)
        if serializer.is_valid():
            rider = serializer.save()
            return Response(
                {
                    'message': 'Signup successful. Please verify OTP.',
                    'rider_id': str(rider.id),
                    'phone': rider.phone,
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RiderLoginView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        phone = request.data.get('phone', '').strip()
        password = request.data.get('password', '')

        try:
            rider = Rider.objects.get(phone=phone)
        except Rider.DoesNotExist:
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        if not rider.check_password(password):
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        refresh = RefreshToken.for_user(rider)
        return Response({
            'access_token': str(refresh.access_token),
            'token': str(refresh.access_token),
            'refresh_token': str(refresh),
            'rider': RiderSerializer(rider, context={'request': request}).data,
        })


# ─── Authenticated rider endpoints ────────────────────────────────────────────

class RiderProfileView(APIView):
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get(self, request):
        return Response(RiderSerializer(request.user, context={'request': request}).data)

    def put(self, request):
        serializer = RiderSerializer(
            request.user, data=request.data, partial=True, context={'request': request}
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RiderStatusView(APIView):
    def post(self, request):
        status_value = request.data.get('status')
        valid_statuses = {choice[0] for choice in Rider.RIDER_STATUS_CHOICES}
        if status_value not in valid_statuses:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)

        # Block offline/online toggle for non-approved riders
        if request.user.account_status != 'approved' and status_value != 'offline':
            return Response(
                {'error': 'Account not approved. Contact admin.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        request.user.current_status = status_value
        request.user.save(update_fields=['current_status', 'last_active'])
        return Response({'status': status_value, 'message': 'Status updated'})


class RiderStatusCheckView(APIView):
    """Lightweight endpoint so the rider app can poll for account_status changes."""
    def get(self, request):
        return Response({
            'account_status': request.user.account_status,
            'is_verified': request.user.is_verified,
        })


class ActiveRidersView(APIView):
    def get(self, request):
        from apps.orders.models import Order

        riders = Rider.objects.filter(
            current_status__in=['online', 'busy'],
            account_status='approved',
        ).order_by('current_status', 'first_name')

        data = []
        for rider in riders:
            if rider.current_status == 'busy':
                active_order = Order.objects.filter(
                    assigned_rider=rider,
                    status__in=['accepted', 'picked_up', 'in_transit', 'reached'],
                ).values('to_latitude', 'to_longitude', 'distance_in_km').first()
                if active_order:
                    if rider.current_latitude is not None and rider.current_longitude is not None:
                        dist = haversine_km(
                            rider.current_latitude, rider.current_longitude,
                            active_order['to_latitude'], active_order['to_longitude'],
                        )
                        if dist >= MAX_ORDER_DISTANCE_KM:
                            continue
                    elif active_order['distance_in_km'] >= MAX_ORDER_DISTANCE_KM:
                        continue

            tracking = getattr(rider, 'current_tracking', None)
            data.append({
                **RiderSerializer(rider, context={'request': request}).data,
                'tracking': {
                    'latitude': tracking.latitude,
                    'longitude': tracking.longitude,
                    'order_id': str(tracking.order_id) if tracking.order_id else None,
                    'is_tracking': tracking.is_tracking,
                    'updated_at': tracking.updated_at,
                } if tracking else None,
            })
        return Response(data)
