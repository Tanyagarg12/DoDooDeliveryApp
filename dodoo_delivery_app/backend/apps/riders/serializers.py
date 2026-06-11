from rest_framework import serializers

from apps.riders.models import Rider


class RiderSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password2 = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = Rider
        fields = [
            "phone",
            "first_name",
            "last_name",
            "email",
            "password",
            "password2",
            "driving_license_number",
            "aadhar_number",
        ]
        extra_kwargs = {
            "last_name": {"required": False, "allow_blank": True},
            "email": {"required": False, "allow_blank": True},
            "driving_license_number": {"required": False, "allow_blank": True},
            "aadhar_number": {"required": False, "allow_blank": True},
        }

    def validate(self, attrs):
        if attrs.get("password") != attrs.get("password2"):
            raise serializers.ValidationError("Passwords don't match")
        return attrs

    def create(self, validated_data):
        validated_data.pop("password2")
        password = validated_data.pop("password")
        phone = validated_data["phone"]
        username = phone
        rider = Rider.objects.create_user(username=username, password=password, **validated_data)
        return rider


class RiderSerializer(serializers.ModelSerializer):
    profile_picture_url = serializers.SerializerMethodField()

    class Meta:
        model = Rider
        fields = [
            "id",
            "phone",
            "first_name",
            "last_name",
            "email",
            "address",
            "profile_picture",
            "profile_picture_url",
            "driving_license_number",
            "aadhar_number",
            "bank_account_number",
            "bank_ifsc_code",
            "is_verified",
            "is_document_verified",
            "current_status",
            "wallet_balance",
            "rating",
            "total_orders",
        ]
        read_only_fields = [
            "id",
            "profile_picture_url",
            "is_verified",
            "is_document_verified",
            "wallet_balance",
            "rating",
            "total_orders",
        ]

    def get_profile_picture_url(self, obj):
        if not obj.profile_picture:
            return ""
        request = self.context.get("request")
        url = obj.profile_picture.url
        return request.build_absolute_uri(url) if request else url
