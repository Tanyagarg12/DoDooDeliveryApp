from rest_framework import serializers

from apps.riders.models import Rider, RiderApprovalLog


class RiderRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for OTP-only rider registration with document uploads."""

    class Meta:
        model = Rider
        fields = [
            'phone', 'first_name', 'last_name', 'email', 'address',
            'aadhar_number', 'driving_license_number',
            'profile_picture', 'aadhar_front', 'aadhar_back', 'driving_license_image',
        ]
        extra_kwargs = {
            'last_name': {'required': False, 'allow_blank': True},
            'email': {'required': False, 'allow_blank': True, 'allow_null': True},
            'address': {'required': False, 'allow_blank': True, 'allow_null': True},
            'aadhar_number': {'required': False, 'allow_blank': True, 'allow_null': True},
            'driving_license_number': {'required': False, 'allow_blank': True, 'allow_null': True},
            'profile_picture': {'required': False, 'allow_null': True},
            'aadhar_front': {'required': False, 'allow_null': True},
            'aadhar_back': {'required': False, 'allow_null': True},
            'driving_license_image': {'required': False, 'allow_null': True},
        }

    def create(self, validated_data):
        phone = validated_data['phone']
        rider = Rider(**validated_data)
        rider.username = phone
        rider.set_unusable_password()
        rider.account_status = 'pending'
        rider.save()
        return rider


class RiderSignupSerializer(serializers.ModelSerializer):
    """Legacy serializer kept for backward compatibility."""
    password = serializers.CharField(write_only=True, min_length=6)
    password2 = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = Rider
        fields = [
            'phone', 'first_name', 'last_name', 'email',
            'password', 'password2',
            'driving_license_number', 'aadhar_number',
        ]
        extra_kwargs = {
            'last_name': {'required': False, 'allow_blank': True},
            'email': {'required': False, 'allow_blank': True},
            'driving_license_number': {'required': False, 'allow_blank': True},
            'aadhar_number': {'required': False, 'allow_blank': True},
        }

    def validate(self, attrs):
        if attrs.get('password') != attrs.get('password2'):
            raise serializers.ValidationError("Passwords don't match")
        return attrs

    def create(self, validated_data):
        validated_data.pop('password2')
        password = validated_data.pop('password')
        phone = validated_data['phone']
        rider = Rider.objects.create_user(username=phone, password=password, **validated_data)
        return rider


class RiderSerializer(serializers.ModelSerializer):
    profile_picture_url = serializers.SerializerMethodField()
    aadhar_front_url = serializers.SerializerMethodField()
    aadhar_back_url = serializers.SerializerMethodField()
    driving_license_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Rider
        fields = [
            'id', 'phone', 'first_name', 'last_name', 'email', 'address',
            'profile_picture', 'profile_picture_url',
            'driving_license_number', 'driving_license_image', 'driving_license_image_url',
            'aadhar_number', 'aadhar_front', 'aadhar_front_url',
            'aadhar_back', 'aadhar_back_url',
            'bank_account_number', 'bank_ifsc_code',
            'is_verified', 'is_document_verified',
            'account_status',
            'current_status', 'wallet_balance', 'rating', 'total_orders',
        ]
        read_only_fields = [
            'id', 'profile_picture_url', 'aadhar_front_url', 'aadhar_back_url',
            'driving_license_image_url', 'is_verified', 'is_document_verified',
            'account_status', 'wallet_balance', 'rating', 'total_orders',
        ]

    def _build_url(self, obj, field_name):
        field = getattr(obj, field_name, None)
        if not field:
            return ''
        request = self.context.get('request')
        url = field.url
        return request.build_absolute_uri(url) if request else url

    def get_profile_picture_url(self, obj):
        return self._build_url(obj, 'profile_picture')

    def get_aadhar_front_url(self, obj):
        return self._build_url(obj, 'aadhar_front')

    def get_aadhar_back_url(self, obj):
        return self._build_url(obj, 'aadhar_back')

    def get_driving_license_image_url(self, obj):
        return self._build_url(obj, 'driving_license_image')


class RiderApprovalLogSerializer(serializers.ModelSerializer):
    admin_name = serializers.SerializerMethodField()
    admin_username = serializers.SerializerMethodField()

    class Meta:
        model = RiderApprovalLog
        fields = ['id', 'action', 'reason', 'timestamp', 'admin_name', 'admin_username']

    def get_admin_name(self, obj):
        if obj.admin:
            return obj.admin.get_full_name() or obj.admin.username
        return 'System'

    def get_admin_username(self, obj):
        return obj.admin.username if obj.admin else 'system'


class AdminRiderListSerializer(serializers.ModelSerializer):
    profile_picture_url = serializers.SerializerMethodField()
    full_name = serializers.SerializerMethodField()
    latest_log = serializers.SerializerMethodField()

    class Meta:
        model = Rider
        fields = [
            'id', 'phone', 'full_name', 'email', 'account_status',
            'current_status', 'is_verified', 'is_document_verified',
            'profile_picture_url', 'joined_date', 'latest_log',
            'rating', 'total_orders',
        ]

    def get_profile_picture_url(self, obj):
        if not obj.profile_picture:
            return ''
        request = self.context.get('request')
        return request.build_absolute_uri(obj.profile_picture.url) if request else obj.profile_picture.url

    def get_full_name(self, obj):
        return obj.get_full_name() or '—'

    def get_latest_log(self, obj):
        log = obj.approval_logs.first()
        if log:
            return RiderApprovalLogSerializer(log).data
        return None


class AdminRiderDetailSerializer(serializers.ModelSerializer):
    profile_picture_url = serializers.SerializerMethodField()
    aadhar_front_url = serializers.SerializerMethodField()
    aadhar_back_url = serializers.SerializerMethodField()
    driving_license_image_url = serializers.SerializerMethodField()
    full_name = serializers.SerializerMethodField()
    approval_logs = serializers.SerializerMethodField()

    class Meta:
        model = Rider
        fields = [
            'id', 'phone', 'full_name', 'first_name', 'last_name', 'email', 'address',
            'account_status', 'current_status', 'is_verified', 'is_document_verified',
            'aadhar_number', 'driving_license_number',
            'profile_picture_url', 'aadhar_front_url', 'aadhar_back_url',
            'driving_license_image_url', 'joined_date', 'last_active',
            'rating', 'total_orders', 'wallet_balance', 'approval_logs',
        ]

    def _url(self, obj, field):
        f = getattr(obj, field, None)
        if not f:
            return ''
        req = self.context.get('request')
        return req.build_absolute_uri(f.url) if req else f.url

    def get_profile_picture_url(self, obj): return self._url(obj, 'profile_picture')
    def get_aadhar_front_url(self, obj): return self._url(obj, 'aadhar_front')
    def get_aadhar_back_url(self, obj): return self._url(obj, 'aadhar_back')
    def get_driving_license_image_url(self, obj): return self._url(obj, 'driving_license_image')

    def get_full_name(self, obj):
        return obj.get_full_name() or '—'

    def get_approval_logs(self, obj):
        logs = obj.approval_logs.all()[:20]
        return RiderApprovalLogSerializer(logs, many=True).data
