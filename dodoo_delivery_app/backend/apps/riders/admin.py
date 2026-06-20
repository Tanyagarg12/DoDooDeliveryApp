from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html

from .models import Rider


@admin.register(Rider)
class RiderAdmin(UserAdmin):
    # ── List view ────────────────────────────────────────────────────────────
    list_display = (
        "phone", "full_name", "email",
        "account_status_badge", "current_status",
        "is_verified", "joined_date",
    )
    list_filter = ("account_status", "current_status", "is_verified", "is_document_verified")
    search_fields = ("phone", "first_name", "last_name", "email")
    ordering = ("-joined_date",)
    list_per_page = 25

    # ── Detail view ──────────────────────────────────────────────────────────
    fieldsets = (
        ("Account Status", {
            "fields": ("account_status",),
            "classes": ("wide",),
            "description": "Change approval status here. New riders start as 'Pending'.",
        }),
        ("Personal Info", {
            "fields": ("first_name", "last_name", "email", "phone", "address"),
        }),
        ("Documents", {
            "fields": (
                "aadhar_number", "aadhar_front", "aadhar_back",
                "driving_license_number", "driving_license_image",
                "profile_picture",
            ),
        }),
        ("Verification", {
            "fields": ("is_verified", "is_document_verified"),
        }),
        ("Rider Stats", {
            "fields": (
                "current_status", "rating", "total_orders",
                "total_earnings", "wallet_balance",
            ),
        }),
        ("Auth (internal)", {
            "fields": ("username", "password"),
            "classes": ("collapse",),
        }),
        ("Permissions", {
            "fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions"),
            "classes": ("collapse",),
        }),
    )

    readonly_fields = ("joined_date", "last_active", "current_otp")

    # ── Bulk actions ─────────────────────────────────────────────────────────
    actions = ["approve_riders", "reject_riders", "suspend_riders", "reset_to_pending"]

    @admin.action(description="✅ Approve selected riders")
    def approve_riders(self, request, queryset):
        updated = queryset.update(account_status="approved")
        self.message_user(request, f"{updated} rider(s) approved.")

    @admin.action(description="❌ Reject selected riders")
    def reject_riders(self, request, queryset):
        updated = queryset.update(account_status="rejected")
        self.message_user(request, f"{updated} rider(s) rejected.")

    @admin.action(description="⛔ Suspend selected riders")
    def suspend_riders(self, request, queryset):
        updated = queryset.update(account_status="suspended")
        self.message_user(request, f"{updated} rider(s) suspended.")

    @admin.action(description="🔄 Reset selected riders to Pending")
    def reset_to_pending(self, request, queryset):
        updated = queryset.update(account_status="pending")
        self.message_user(request, f"{updated} rider(s) reset to pending.")

    # ── Computed columns ─────────────────────────────────────────────────────
    @admin.display(description="Name")
    def full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip() or "—"

    @admin.display(description="Account Status")
    def account_status_badge(self, obj):
        colours = {
            "pending":   ("#92400E", "#FEF3C7"),   # amber
            "approved":  ("#065F46", "#D1FAE5"),   # green
            "rejected":  ("#991B1B", "#FEE2E2"),   # red
            "suspended": ("#92400E", "#FFEDD5"),   # orange
        }
        text_colour, bg_colour = colours.get(obj.account_status, ("#374151", "#F3F4F6"))
        return format_html(
            '<span style="'
            'background:{bg};color:{fg};'
            'padding:2px 10px;border-radius:999px;'
            'font-size:12px;font-weight:600;white-space:nowrap'
            '">{label}</span>',
            bg=bg_colour,
            fg=text_colour,
            label=obj.get_account_status_display(),
        )
