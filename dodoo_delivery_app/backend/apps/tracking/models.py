from django.db import models
from django.core.validators import MinValueValidator
import uuid
from apps.riders.models import Rider
from apps.orders.models import Order

class RiderTracking(models.Model):
    """Real-time rider tracking"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.OneToOneField(Rider, on_delete=models.CASCADE, related_name='current_tracking')
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name='tracking')
    
    latitude = models.FloatField()
    longitude = models.FloatField()
    speed = models.FloatField(null=True, blank=True, help_text="Speed in km/h")
    bearing = models.FloatField(null=True, blank=True, help_text="Direction in degrees")
    accuracy = models.FloatField(null=True, blank=True, help_text="GPS accuracy in meters")
    
    distance_traveled = models.FloatField(default=0, help_text="Distance traveled in current order in km")
    
    is_tracking = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True, db_index=True)
    
    class Meta:
        db_table = 'rider_tracking'
        indexes = [
            models.Index(fields=['rider', '-updated_at']),
        ]


class RiderLocationHistory(models.Model):
    """Historical location data for analytics"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name='location_history')
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    
    latitude = models.FloatField()
    longitude = models.FloatField()
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    
    class Meta:
        db_table = 'rider_location_history'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['rider', 'order', '-timestamp']),
        ]


class Earning(models.Model):
    """Track earnings per order"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name='earnings')
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='earning')
    
    distance = models.FloatField(validators=[MinValueValidator(0)])
    rate_per_km = models.DecimalField(max_digits=5, decimal_places=2)
    minimum_fare = models.DecimalField(max_digits=8, decimal_places=2)
    
    calculated_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    final_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    
    bonus = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    deduction = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('calculated', 'Calculated'),
            ('credited', 'Credited to wallet'),
        ],
        default='pending'
    )
    
    credited_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'earnings'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['rider', '-created_at']),
        ]
    
    def __str__(self):
        return f"{self.rider} - {self.final_amount}Rs"


class RiderWallet(models.Model):
    """Rider wallet management"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.OneToOneField(Rider, on_delete=models.CASCADE, related_name='wallet')
    
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_earned = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_withdrawn = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'rider_wallets'
    
    def __str__(self):
        return f"{self.rider.first_name} - ₹{self.balance}"


class WalletTransaction(models.Model):
    """Track all wallet transactions"""
    TRANSACTION_TYPES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
        ('withdrawal', 'Withdrawal'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wallet = models.ForeignKey(RiderWallet, on_delete=models.CASCADE, related_name='transactions')
    
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.CharField(max_length=500)
    
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    earning = models.ForeignKey(Earning, on_delete=models.SET_NULL, null=True, blank=True)
    
    balance_before = models.DecimalField(max_digits=10, decimal_places=2)
    balance_after = models.DecimalField(max_digits=10, decimal_places=2)
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'wallet_transactions'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['wallet', '-created_at']),
        ]


class WithdrawalRequest(models.Model):
    """Track rider withdrawal requests"""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name='withdrawal_requests')
    
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(100)])
    bank_account = models.CharField(max_length=20)
    bank_ifsc = models.CharField(max_length=11)
    
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    transaction_id = models.CharField(max_length=100, null=True, blank=True)
    notes = models.TextField(null=True, blank=True)
    
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        db_table = 'withdrawal_requests'
        ordering = ['-requested_at']
