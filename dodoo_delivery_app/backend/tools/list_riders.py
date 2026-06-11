"""List Rider records from the Django DB for debugging."""
import os
import sys
import django

# Ensure the backend package is on sys.path so `import config` works
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, backend_dir)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

from apps.riders.models import Rider

rs = Rider.objects.all().values('id','phone','first_name','driving_license_number','aadhar_number','is_verified')
for r in rs:
    print(r)
