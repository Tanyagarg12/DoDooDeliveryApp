from rest_framework import serializers

from apps.orders.models import FareConfig, Order, OrderNotification


class FareConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = FareConfig
        fields = ["id", "rate_per_km", "minimum_fare", "is_active", "updated_at"]
        read_only_fields = ["id", "is_active", "updated_at"]


class OrderSerializer(serializers.ModelSerializer):
    assigned_rider_phone = serializers.CharField(source="assigned_rider.phone", read_only=True)
    assigned_rider_name = serializers.SerializerMethodField()
    tracking = serializers.SerializerMethodField()
    delivery_location = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = "__all__"
        read_only_fields = ["id", "created_at", "status_updated_at"]

    def get_assigned_rider_name(self, obj):
        if not obj.assigned_rider:
            return ""
        return f"{obj.assigned_rider.first_name} {obj.assigned_rider.last_name}".strip()

    def get_tracking(self, obj):
        latest = obj.tracking.order_by("-updated_at").first()
        if not latest:
            return None
        return {
            "latitude": latest.latitude,
            "longitude": latest.longitude,
            "speed": latest.speed,
            "bearing": latest.bearing,
            "accuracy": latest.accuracy,
            "is_tracking": latest.is_tracking,
            "updated_at": latest.updated_at,
        }

    def get_delivery_location(self, obj):
        latest_tracking = obj.tracking.order_by("-updated_at").first()
        if latest_tracking:
            return {
                "latitude": latest_tracking.latitude,
                "longitude": latest_tracking.longitude,
                "updated_at": latest_tracking.updated_at,
                "source": "live",
            }

        latest_history = obj.riderlocationhistory_set.order_by("-timestamp").first()
        if not latest_history:
            return None
        return {
            "latitude": latest_history.latitude,
            "longitude": latest_history.longitude,
            "updated_at": latest_history.timestamp,
            "source": "last",
        }


class OrderOfferSerializer(serializers.ModelSerializer):
    order = OrderSerializer(read_only=True)

    class Meta:
        model = OrderNotification
        fields = [
            "id",
            "order",
            "is_notified",
            "is_accepted",
            "is_rejected",
            "notified_at",
            "accepted_at",
            "rejected_at",
        ]
