"""Test signup, send-otp, verify-otp and login endpoints sequentially."""
import os
import sys
import json
import http.client

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, backend_dir)

BASE = ('127.0.0.1', 8000)

def post(path, payload):
    conn = http.client.HTTPConnection(BASE[0], BASE[1], timeout=10)
    headers = {'Content-Type': 'application/json'}
    body = json.dumps(payload)
    try:
        conn.request('POST', path, body, headers)
        res = conn.getresponse()
        return res.status, res.read().decode()
    except Exception as e:
        return None, str(e)
    finally:
        conn.close()

phone = "+919111111111"
signup_payload = {
    'phone': phone,
    'first_name': 'AutoTest',
    'password': 'pass123',
    'password2': 'pass123'
}

print('Signup ->', post('/api/riders/signup/', signup_payload))
print('Send OTP ->', post('/api/riders/send-otp/', {'phone': phone}))
print('Verify OTP (correct) ->', post('/api/riders/verify-otp/', {'phone': phone, 'otp': '123456'}))
print('Login ->', post('/api/riders/login/', {'phone': phone, 'password': 'pass123'}))
