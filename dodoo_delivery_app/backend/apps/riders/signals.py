from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.mail import send_mail
from django.conf import settings

from apps.riders.models import Rider, RiderApprovalLog


@receiver(post_save, sender=Rider)
def on_rider_created(sender, instance, created, **kwargs):
    """Email admin when a non-staff rider registers."""
    if not created or instance.is_staff:
        return
    admin_email = getattr(settings, 'ADMIN_NOTIFICATION_EMAIL', 'admin@dodoo.com')
    name = instance.get_full_name() or instance.phone
    send_mail(
        subject=f'[DoDoo] New rider registration: {name}',
        message=(
            f'A new rider is awaiting approval.\n\n'
            f'Name: {instance.get_full_name()}\n'
            f'Phone: {instance.phone}\n'
            f'Email: {instance.email or "-"}\n'
            f'Joined: {instance.joined_date}\n\n'
            f'Review at: /admin/riders/rider/{instance.id}/change/'
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[admin_email],
        fail_silently=True,
    )
    # Create audit log entry for registration
    RiderApprovalLog.objects.create(
        rider=instance,
        admin=None,
        action='registered',
        reason='',
    )
