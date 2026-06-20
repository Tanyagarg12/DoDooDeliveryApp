import random
from django.contrib.auth import authenticate
from rest_framework import status
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.riders.models import Rider, RiderApprovalLog
from apps.riders.serializers import (
    AdminRiderDetailSerializer,
    AdminRiderListSerializer,
    RiderApprovalLogSerializer,
)


class AdminLoginView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        username = request.data.get('username', '').strip()
        password = request.data.get('password', '')
        if not username or not password:
            return Response({'error': 'Username and password are required.'}, status=400)

        user = authenticate(request, username=username, password=password)
        if user is None or not user.is_staff:
            return Response({'error': 'Invalid credentials or insufficient permissions.'}, status=401)

        refresh = RefreshToken.for_user(user)
        return Response({
            'access_token': str(refresh.access_token),
            'refresh_token': str(refresh),
            'admin': {
                'id': str(user.id),
                'username': user.username,
                'name': user.get_full_name() or user.username,
                'email': user.email,
            },
        })


class AdminRiderListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        status_filter = request.query_params.get('status', 'all')
        search = request.query_params.get('search', '').strip()

        qs = Rider.objects.filter(is_staff=False).prefetch_related('approval_logs').order_by('-joined_date')

        if status_filter != 'all':
            qs = qs.filter(account_status=status_filter)

        if search:
            from django.db.models import Q
            qs = qs.filter(
                Q(phone__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(email__icontains=search)
            )

        base_qs = Rider.objects.filter(is_staff=False)
        counts = {
            'all': base_qs.count(),
            'pending': base_qs.filter(account_status='pending').count(),
            'approved': base_qs.filter(account_status='approved').count(),
            'rejected': base_qs.filter(account_status='rejected').count(),
            'suspended': base_qs.filter(account_status='suspended').count(),
        }

        return Response({
            'riders': AdminRiderListSerializer(qs, many=True, context={'request': request}).data,
            'counts': counts,
        })


class AdminRiderDetailView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request, rider_id):
        try:
            rider = Rider.objects.prefetch_related('approval_logs').get(id=rider_id, is_staff=False)
        except Rider.DoesNotExist:
            return Response({'error': 'Rider not found.'}, status=404)

        return Response(AdminRiderDetailSerializer(rider, context={'request': request}).data)


class AdminRiderActionView(APIView):
    permission_classes = [IsAdminUser]

    ACTION_MAP = {
        'approve': 'approved',
        'reject': 'rejected',
        'suspend': 'suspended',
        'reactivate': 'pending',
    }
    LOG_ACTION_MAP = {
        'approve': 'approved',
        'reject': 'rejected',
        'suspend': 'suspended',
        'reactivate': 'reactivated',
    }

    def post(self, request, rider_id):
        action = request.data.get('action', '').strip()
        reason = request.data.get('reason', '').strip()

        if action not in self.ACTION_MAP:
            return Response({'error': f'Invalid action. Choose from: {list(self.ACTION_MAP)}'}, status=400)

        if action in ('reject', 'suspend') and not reason:
            return Response({'error': f'A reason is required for "{action}".'}, status=400)

        try:
            rider = Rider.objects.get(id=rider_id, is_staff=False)
        except Rider.DoesNotExist:
            return Response({'error': 'Rider not found.'}, status=404)

        new_status = self.ACTION_MAP[action]
        rider.account_status = new_status
        rider.save(update_fields=['account_status', 'last_active'])

        RiderApprovalLog.objects.create(
            rider=rider,
            admin=request.user,
            action=self.LOG_ACTION_MAP[action],
            reason=reason,
        )

        # FCM push notification stub — replace with real FCM call in production
        # if rider.fcm_token:
        #     _send_fcm_status_change(rider.fcm_token, new_status, reason)

        return Response({
            'message': f'Rider {action}d successfully.',
            'account_status': new_status,
            'rider_id': str(rider.id),
        })


class AdminRiderApprovalLogsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request, rider_id):
        try:
            rider = Rider.objects.get(id=rider_id, is_staff=False)
        except Rider.DoesNotExist:
            return Response({'error': 'Rider not found.'}, status=404)

        logs = rider.approval_logs.all()
        return Response({'logs': RiderApprovalLogSerializer(logs, many=True).data})


class AdminDashboardStatsView(APIView):
    """Quick stats for the admin dashboard header."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        base = Rider.objects.filter(is_staff=False)
        return Response({
            'total': base.count(),
            'pending': base.filter(account_status='pending').count(),
            'approved': base.filter(account_status='approved').count(),
            'rejected': base.filter(account_status='rejected').count(),
            'suspended': base.filter(account_status='suspended').count(),
            'online_now': base.filter(
                account_status='approved', current_status__in=['online', 'busy']
            ).count(),
        })
