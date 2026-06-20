"""Add account_status and current_otp fields to Rider."""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("riders", "0002_make_fields_optional"),
    ]

    operations = [
        migrations.AddField(
            model_name="rider",
            name="account_status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending Approval"),
                    ("approved", "Approved"),
                    ("rejected", "Rejected"),
                    ("suspended", "Suspended"),
                ],
                default="pending",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="rider",
            name="current_otp",
            field=models.CharField(blank=True, max_length=6, null=True),
        ),
    ]
