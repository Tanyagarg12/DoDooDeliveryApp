from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator
import uuid

class Rider(AbstractUser):
    """Rider user model with additional fields"""
    RIDER_STATUS_CHOICES = [
        ('offline', 'Offline'),
        ('online', 'Online'),
        ('busy', 'Busy'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=15, unique=True)
    profile_picture = models.FileField(upload_to='rider_profiles/', null=True, blank=True)
    address = models.TextField(null=True, blank=True)
    driving_license_number = models.CharField(max_length=50, unique=True, null=True, blank=True)
    driving_license_image = models.FileField(upload_to='driving_licenses/', null=True, blank=True)
    aadhar_number = models.CharField(max_length=12, unique=True, null=True, blank=True)
    aadhar_front = models.FileField(upload_to='aadhar_front/', null=True, blank=True)
    aadhar_back = models.FileField(upload_to='aadhar_back/', null=True, blank=True)
    
    ACCOUNT_STATUS_CHOICES = [
        ('pending', 'Pending Approval'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('suspended', 'Suspended'),
    ]
    account_status = models.CharField(max_length=20, choices=ACCOUNT_STATUS_CHOICES, default='pending')

    current_status = models.CharField(max_length=20, choices=RIDER_STATUS_CHOICES, default='offline')
    current_latitude = models.FloatField(null=True, blank=True)
    current_longitude = models.FloatField(null=True, blank=True)
    current_order_id = models.CharField(max_length=100, null=True, blank=True)
    
    rating = models.FloatField(default=5.0, validators=[MinValueValidator(0), MaxValueValidator(5)])
    total_orders = models.IntegerField(default=0)
    total_earnings = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    bank_account_number = models.CharField(max_length=20, null=True, blank=True)
    bank_ifsc_code = models.CharField(max_length=11, null=True, blank=True)
    
    fcm_token = models.TextField(null=True, blank=True)
    is_verified = models.BooleanField(default=False)

    # Demo OTP — stores the last generated OTP so it can be verified
    current_otp = models.CharField(max_length=6, null=True, blank=True)
    is_document_verified = models.BooleanField(default=False)
    
    joined_date = models.DateTimeField(auto_now_add=True)
    last_active = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'riders'
        ordering = ['-last_active']
    
    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.phone})"


class RiderLocation(models.Model):
    """Track rider location history"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name='locations')
    latitude = models.FloatField()
    longitude = models.FloatField()
    accuracy = models.FloatField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'rider_locations'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['rider', '-timestamp']),
        ]


class RiderRating(models.Model):
    """Track rider ratings from orders"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name='ratings')
    order_id = models.CharField(max_length=100)
    rating = models.IntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'rider_ratings'
        ordering = ['-created_at']


class RiderApprovalLog(models.Model):
    ACTION_CHOICES = [
        ('registered', 'Registered'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('suspended', 'Suspended'),
        ('reactivated', 'Reactivated'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name='approval_logs')
    admin = models.ForeignKey(
        Rider, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='admin_actions',
    )
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    reason = models.TextField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'rider_approval_logs'
        ordering = ['-timestamp']
