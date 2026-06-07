from decimal import Decimal

from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.orders.models import Order
from apps.tracking.models import (
    RiderLocationHistory,
    RiderTracking,
    RiderWallet,
    WalletTransaction,
    WithdrawalRequest,
)


class TrackingHealthView(APIView):
    permission_classes = []
    authentication_classes = []

    def get(self, request):
        return Response({"status": "ok"})


class RiderTrackingView(APIView):
    def get(self, request):
        tracking = getattr(request.user, "current_tracking", None)
        if not tracking:
            return Response({"tracking": None})
        return Response({"tracking": self._serialize(tracking)})

    def post(self, request):
        latitude = request.data.get("latitude")
        longitude = request.data.get("longitude")
        if latitude in [None, ""] or longitude in [None, ""]:
            return Response({"error": "Latitude and longitude are required"}, status=400)

        order = None
        order_id = request.data.get("order_id")
        if order_id:
            order = Order.objects.filter(id=order_id, assigned_rider=request.user).first()

        tracking, _ = RiderTracking.objects.update_or_create(
            rider=request.user,
            defaults={
                "order": order,
                "latitude": latitude,
                "longitude": longitude,
                "speed": request.data.get("speed") or None,
                "bearing": request.data.get("bearing") or None,
                "accuracy": request.data.get("accuracy") or None,
                "is_tracking": request.data.get("is_tracking", True),
            },
        )
        RiderLocationHistory.objects.create(
            rider=request.user,
            order=order,
            latitude=latitude,
            longitude=longitude,
        )
        return Response({"tracking": self._serialize(tracking)})

    def _serialize(self, tracking):
        return {
            "latitude": tracking.latitude,
            "longitude": tracking.longitude,
            "speed": tracking.speed,
            "bearing": tracking.bearing,
            "accuracy": tracking.accuracy,
            "distance_traveled": tracking.distance_traveled,
            "is_tracking": tracking.is_tracking,
            "order_id": str(tracking.order_id) if tracking.order_id else None,
            "updated_at": tracking.updated_at,
        }


def serialize_wallet(wallet):
    return {
        "balance": wallet.balance,
        "total_earned": wallet.total_earned,
        "total_withdrawn": wallet.total_withdrawn,
        "updated_at": wallet.updated_at,
    }


def serialize_withdrawal(request):
    return {
        "id": str(request.id),
        "amount": request.amount,
        "bank_account": request.bank_account,
        "bank_ifsc": request.bank_ifsc,
        "status": request.status,
        "transaction_id": request.transaction_id,
        "requested_at": request.requested_at,
        "processed_at": request.processed_at,
    }


class RiderWalletView(APIView):
    def get(self, request):
        wallet, _ = RiderWallet.objects.get_or_create(rider=request.user)
        withdrawals = WithdrawalRequest.objects.filter(rider=request.user)[:20]
        return Response(
            {
                "wallet": serialize_wallet(wallet),
                "withdrawal_requests": [
                    serialize_withdrawal(item) for item in withdrawals
                ],
            }
        )


class WithdrawalRequestView(APIView):
    def post(self, request):
        amount = request.data.get("amount")
        bank_account = request.data.get("bank_account") or request.user.bank_account_number
        bank_ifsc = request.data.get("bank_ifsc") or request.user.bank_ifsc_code

        if amount in [None, ""]:
            return Response({"error": "Withdrawal amount is required"}, status=400)
        if not bank_account or not bank_ifsc:
            return Response({"error": "Bank account and IFSC are required"}, status=400)

        try:
            amount = Decimal(str(amount))
        except Exception:
            return Response({"error": "Enter a valid withdrawal amount"}, status=400)

        if amount < Decimal("100"):
            return Response({"error": "Minimum withdrawal amount is Rs 100"}, status=400)

        wallet, _ = RiderWallet.objects.get_or_create(rider=request.user)
        if amount > wallet.balance:
            return Response({"error": "Insufficient wallet balance"}, status=400)

        before = wallet.balance
        wallet.balance = before - amount
        wallet.total_withdrawn += amount
        wallet.save(update_fields=["balance", "total_withdrawn", "updated_at"])

        withdrawal = WithdrawalRequest.objects.create(
            rider=request.user,
            amount=amount,
            bank_account=bank_account,
            bank_ifsc=bank_ifsc,
            status="completed",
            processed_at=timezone.now(),
            transaction_id=f"AUTO-{timezone.now().strftime('%Y%m%d%H%M%S')}",
            notes="Auto accepted from rider app.",
        )
        WalletTransaction.objects.create(
            wallet=wallet,
            transaction_type="withdrawal",
            amount=amount,
            description=f"Withdrawal request {withdrawal.id}",
            balance_before=before,
            balance_after=wallet.balance,
        )
        request.user.wallet_balance = wallet.balance
        request.user.save(update_fields=["wallet_balance", "last_active"])

        return Response(
            {
                "wallet": serialize_wallet(wallet),
                "withdrawal": serialize_withdrawal(withdrawal),
            },
            status=201,
        )
