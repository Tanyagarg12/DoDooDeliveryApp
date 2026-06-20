"""Add RiderApprovalLog model."""
import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('riders', '0003_add_account_status_and_otp'),
    ]

    operations = [
        migrations.CreateModel(
            name='RiderApprovalLog',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('action', models.CharField(
                    choices=[
                        ('registered', 'Registered'),
                        ('approved', 'Approved'),
                        ('rejected', 'Rejected'),
                        ('suspended', 'Suspended'),
                        ('reactivated', 'Reactivated'),
                    ],
                    max_length=20,
                )),
                ('reason', models.TextField(blank=True, null=True)),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('admin', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='admin_actions',
                    to=settings.AUTH_USER_MODEL,
                )),
                ('rider', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='approval_logs',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={'db_table': 'rider_approval_logs', 'ordering': ['-timestamp']},
        ),
    ]
