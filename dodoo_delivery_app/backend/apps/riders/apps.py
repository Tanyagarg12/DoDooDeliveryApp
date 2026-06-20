from django.apps import AppConfig


class RidersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.riders'

    def ready(self):
        import apps.riders.signals  # noqa: F401
