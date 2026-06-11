"""Helper script to create a test rider and verify password check.
Run: python tools/create_test_rider.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

from apps.riders.models import Rider

phone = '+91900000001'
if not Rider.objects.filter(phone=phone).exists():
    r = Rider.objects.create_user(username=phone, phone=phone, password='test123', first_name='Admin', driving_license_number=None, aadhar_number=None, is_verified=True)
    print('Created test rider:', r.phone)
else:
    r = Rider.objects.get(phone=phone)
    print('Test rider exists, password ok:', r.check_password('test123'))
