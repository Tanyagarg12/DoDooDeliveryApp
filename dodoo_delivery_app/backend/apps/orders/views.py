from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.orders.models import FareConfig, Order, OrderNotification, OrderStatusLog
from apps.orders.serializers import (
    FareConfigSerializer,
    OrderOfferSerializer,
    OrderSerializer,
)
from apps.riders.models import Rider
from apps.riders.serializers import RiderSerializer
from apps.tracking.models import (
    Earning,
    RiderWallet,
    WalletTransaction,
    WithdrawalRequest,
)
from apps.tracking.views import serialize_wallet, serialize_withdrawal


class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer

    def perform_create(self, serializer):
        fare_config = FareConfig.active()
        order = serializer.save(
            rate_per_km=fare_config.rate_per_km,
            minimum_fare=fare_config.minimum_fare,
        )
        order.total_earning = order.calculate_earning()
        order.save(update_fields=["rate_per_km", "minimum_fare", "total_earning"])
        self._notify_available_riders(order)

    @action(detail=False, methods=["get", "post"], url_path="pricing-config")
    def pricing_config(self, request):
        fare_config = FareConfig.active()
        if request.method == "GET":
            return Response(FareConfigSerializer(fare_config).data)

        serializer = FareConfigSerializer(fare_config, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(is_active=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="rider-dashboard")
    def rider_dashboard(self, request):
        rider = request.user
        self._ensure_pending_offers_for(rider)

        active_orders = Order.objects.filter(
            assigned_rider=rider,
            status__in=["accepted", "picked_up", "in_transit", "reached"],
        ).order_by("-created_at")
        pending_offers = OrderNotification.objects.filter(
            rider=rider,
            order__status="pending",
            is_accepted=False,
            is_rejected=False,
        ).select_related("order")
        completed_orders = Order.objects.filter(assigned_rider=rider, status="completed")
        order_history = Order.objects.filter(
            assigned_rider=rider,
            status__in=["completed", "cancelled"],
        ).order_by("-created_at")[:30]
        wallet, _ = RiderWallet.objects.get_or_create(rider=rider)
        withdrawals = WithdrawalRequest.objects.filter(rider=rider)[:10]

        earnings = completed_orders.aggregate(total=Sum("total_earning"))["total"] or 0
        return Response(
            {
                "rider": RiderSerializer(rider, context={"request": request}).data,
                "active_orders": OrderSerializer(active_orders, many=True).data,
                "order_history": OrderSerializer(order_history, many=True).data,
                "pending_offers": OrderOfferSerializer(pending_offers, many=True).data,
                "earnings_summary": {
                    "today": earnings,
                    "week": earnings,
                    "month": earnings,
                    "completed_orders": completed_orders.count(),
                },
                "wallet": serialize_wallet(wallet),
                "withdrawal_requests": [
                    serialize_withdrawal(item) for item in withdrawals
                ],
            }
        )

    @action(detail=False, methods=["get"], url_path="offers")
    def offers(self, request):
        self._ensure_pending_offers_for(request.user)
        offers = OrderNotification.objects.filter(
            rider=request.user,
            order__status="pending",
            is_accepted=False,
            is_rejected=False,
        ).select_related("order")
        return Response(OrderOfferSerializer(offers, many=True).data)

    @action(detail=True, methods=["post"], url_path="accept")
    def accept(self, request, pk=None):
        order = self.get_object()
        rider = request.user
        if order.status != "pending":
            return Response({"error": "Order is no longer available"}, status=status.HTTP_400_BAD_REQUEST)

        notification, _ = OrderNotification.objects.get_or_create(order=order, rider=rider)
        notification.is_accepted = True
        notification.is_rejected = False
        notification.accepted_at = timezone.now()
        notification.save(update_fields=["is_accepted", "is_rejected", "accepted_at"])

        order.assigned_rider = rider
        order.status = "accepted"
        order.accepted_at = timezone.now()
        if order.total_earning is None:
            order.total_earning = order.calculate_earning()
        order.save(update_fields=["assigned_rider", "status", "accepted_at", "total_earning", "status_updated_at"])
        OrderStatusLog.objects.create(order=order, previous_status="pending", new_status="accepted", changed_by="rider")
        Rider.objects.filter(pk=rider.pk).update(current_status="busy")
        rider.current_status = "busy"
        return Response(OrderSerializer(order).data)

    @action(detail=True, methods=["post"], url_path="reject")
    def reject(self, request, pk=None):
        order = self.get_object()
        notification, _ = OrderNotification.objects.get_or_create(order=order, rider=request.user)
        notification.is_rejected = True
        notification.is_accepted = False
        notification.rejected_at = timezone.now()
        notification.save(update_fields=["is_rejected", "is_accepted", "rejected_at"])
        return Response({"message": "Offer rejected"})

    @action(detail=True, methods=["post"], url_path="status")
    def update_status(self, request, pk=None):
        order = self.get_object()
        rider = request.user
        next_status = request.data.get("status")
        valid_flow = ["accepted", "picked_up", "in_transit", "reached", "completed"]

        if next_status not in valid_flow:
            return Response({"error": "Invalid order status"}, status=status.HTTP_400_BAD_REQUEST)
        if order.assigned_rider_id != rider.id:
            return Response({"error": "This order is assigned to another rider"}, status=status.HTTP_403_FORBIDDEN)
        if next_status == order.status:
            return Response(OrderSerializer(order).data)
        if valid_flow.index(next_status) < valid_flow.index(order.status):
            return Response({"error": "Order cannot move backwards"}, status=status.HTTP_400_BAD_REQUEST)

        previous_status = order.status
        order.status = next_status
        now = timezone.now()
        update_fields = ["status", "status_updated_at"]
        if next_status == "picked_up":
            order.picked_up_at = now
            update_fields.append("picked_up_at")
        if next_status == "completed":
            order.completed_at = now
            update_fields.append("completed_at")
            self._credit_completed_order(order, rider)
        order.save(update_fields=update_fields)
        OrderStatusLog.objects.create(order=order, previous_status=previous_status, new_status=next_status, changed_by="rider")
        if next_status == "completed":
            Rider.objects.filter(pk=rider.pk).update(current_status="online", total_orders=rider.total_orders + 1)
            rider.current_status = "online"
        return Response(OrderSerializer(order).data)

    def _notify_available_riders(self, order):
        riders = Rider.objects.filter(current_status="online", is_verified=True)
        notified_ids = []
        for rider in riders:
            OrderNotification.objects.get_or_create(order=order, rider=rider)
            notified_ids.append(str(rider.id))
        if notified_ids:
            order.notification_sent_to = notified_ids
            order.notification_sent_at = timezone.now()
            order.save(update_fields=["notification_sent_to", "notification_sent_at"])

    def _ensure_pending_offers_for(self, rider):
        if rider.current_status != "online" or not rider.is_verified:
            return
        orders = Order.objects.filter(status="pending", assigned_rider__isnull=True)
        for order in orders:
            notification, created = OrderNotification.objects.get_or_create(order=order, rider=rider)
            if created:
                recipients = [str(item) for item in order.notification_sent_to]
                rider_id = str(rider.id)
                if rider_id not in recipients:
                    recipients.append(rider_id)
                    order.notification_sent_to = recipients
                    order.notification_sent_at = timezone.now()
                    order.save(update_fields=["notification_sent_to", "notification_sent_at"])

    def _credit_completed_order(self, order, rider):
        amount = Decimal(str(order.total_earning or order.calculate_earning()))
        earning, _ = Earning.objects.get_or_create(
            order=order,
            rider=rider,
            defaults={
                "distance": order.distance_in_km,
                "rate_per_km": order.rate_per_km,
                "minimum_fare": order.minimum_fare,
                "calculated_amount": amount,
                "final_amount": amount,
                "status": "credited",
                "credited_at": timezone.now(),
            },
        )
        wallet, _ = RiderWallet.objects.get_or_create(rider=rider)
        if earning.status == "credited" and WalletTransaction.objects.filter(earning=earning).exists():
            return
        before = wallet.balance
        wallet.balance = before + amount
        wallet.total_earned += amount
        wallet.save(update_fields=["balance", "total_earned", "updated_at"])
        Rider.objects.filter(pk=rider.pk).update(wallet_balance=wallet.balance)
        earning.status = "credited"
        earning.final_amount = amount
        earning.credited_at = timezone.now()
        earning.save(update_fields=["status", "final_amount", "credited_at"])
        WalletTransaction.objects.create(
            wallet=wallet,
            transaction_type="credit",
            amount=amount,
            description=f"Order {order.order_number} completed",
            order=order,
            earning=earning,
            balance_before=before,
            balance_after=wallet.balance,
        )
