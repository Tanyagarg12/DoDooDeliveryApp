from django.db import models
from django.core.validators import MinValueValidator
import uuid
from apps.riders.models import Rider

class Order(models.Model):
    """Order model for delivery"""
    ORDER_STATUS_CHOICES = [
        ('pending', 'Pending - Waiting for rider'),
        ('accepted', 'Accepted - Rider accepted'),
        ('picked_up', 'Picked Up - Item collected'),
        ('in_transit', 'In Transit - On the way'),
        ('reached', 'Reached - At destination'),
        ('completed', 'Completed - Order delivered'),
        ('cancelled', 'Cancelled'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    order_number = models.CharField(max_length=50, unique=True, db_index=True)
    
    # Location details
    from_address = models.CharField(max_length=500)
    from_latitude = models.FloatField()
    from_longitude = models.FloatField()
    
    to_address = models.CharField(max_length=500)
    to_latitude = models.FloatField()
    to_longitude = models.FloatField()
    
    # Order details
    items_description = models.TextField()
    distance_in_km = models.FloatField(validators=[MinValueValidator(0)])
    estimated_time_minutes = models.IntegerField(default=30)
    
    # Pricing
    rate_per_km = models.DecimalField(max_digits=5, decimal_places=2, default=8)
    minimum_fare = models.DecimalField(max_digits=8, decimal_places=2, default=50)
    total_earning = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    
    # Rider assignment
    assigned_rider = models.ForeignKey(Rider, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    
    # Status tracking
    status = models.CharField(max_length=20, choices=ORDER_STATUS_CHOICES, default='pending')
    status_updated_at = models.DateTimeField(auto_now=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    picked_up_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    # Customer details
    customer_name = models.CharField(max_length=100, blank=True, default='')
    customer_phone = models.CharField(max_length=20, blank=True, default='')

    # Notifications
    notification_sent_to = models.JSONField(default=list, help_text="List of rider IDs notified")
    notification_sent_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        db_table = 'orders'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['assigned_rider', '-created_at']),
        ]
    
    def __str__(self):
        return f"Order {self.order_number} - {self.status}"
    
    def calculate_earning(self):
        """Calculate earning based on distance and minimum fare"""
        if self.distance_in_km and self.rate_per_km and self.minimum_fare:
            calculated = float(self.distance_in_km) * float(self.rate_per_km)
            return max(calculated, float(self.minimum_fare))
        return float(self.minimum_fare)


class FareConfig(models.Model):
    """Admin-managed fare calculation settings"""
    rate_per_km = models.DecimalField(max_digits=5, decimal_places=2, default=8)
    minimum_fare = models.DecimalField(max_digits=8, decimal_places=2, default=50)
    is_active = models.BooleanField(default=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'fare_configs'
        ordering = ['-updated_at']

    def __str__(self):
        return f"Rs {self.rate_per_km}/km, min Rs {self.minimum_fare}"

    @classmethod
    def active(cls):
        config = cls.objects.filter(is_active=True).order_by("-updated_at").first()
        if config:
            return config
        return cls.objects.create(rate_per_km=8, minimum_fare=50, is_active=True)


class OrderStatusLog(models.Model):
    """Log all order status changes"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='status_logs')
    previous_status = models.CharField(max_length=20)
    new_status = models.CharField(max_length=20)
    changed_by = models.CharField(max_length=100)  # Can be 'system', 'rider', 'admin', etc
    notes = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'order_status_logs'
        ordering = ['-created_at']


class OrderNotification(models.Model):
    """Track which riders were notified about orders"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='rider_notifications')
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE)
    is_notified = models.BooleanField(default=True)
    is_accepted = models.BooleanField(default=False)
    is_rejected = models.BooleanField(default=False)
    accepted_at = models.DateTimeField(null=True, blank=True)
    rejected_at = models.DateTimeField(null=True, blank=True)
    notified_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'order_notifications'
        unique_together = ['order', 'rider']
        ordering = ['-notified_at']
