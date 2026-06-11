"""Simple script to POST login credentials to the running server and print response."""
import http.client
import json

conn = http.client.HTTPConnection('127.0.0.1', 8000, timeout=10)
payload = json.dumps({'phone': '+91900000001', 'password': 'test123'})
headers = {'Content-Type': 'application/json'}
try:
    conn.request('POST', '/api/riders/login/', payload, headers)
    res = conn.getresponse()
    body = res.read().decode()
    print(res.status)
    print(body)
except Exception as e:
    print('Error:', e)
finally:
    conn.close()
