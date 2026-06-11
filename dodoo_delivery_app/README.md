# DoDoo Delivery App

A delivery dispatch platform consisting of three components:

- **Flutter Rider App** — Android/iOS mobile app for delivery riders
- **Django Backend** — REST API with JWT auth, order dispatch, and real-time tracking
- **React Admin Portal** — Web dashboard for order management and fare configuration

---

## Prerequisites

| Tool    | Version           |
| ------- | ----------------- |
| Python  | 3.11+             |
| Flutter | 3.24+ (Dart 3.4+) |
| Node.js | 18+               |
| npm     | 9+                |

---

## 1. Django Backend

### Setup

```bash
cd dodoo_delivery_app/backend

# Create and activate virtual environment
python -m venv .venv

# Windows
.venv\Scripts\activate

# macOS / Linux
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Apply database migrations
python manage.py migrate

# Create a superuser (optional, for Django admin at /admin/)
python manage.py createsuperuser

# Create a test rider account (phone: +91900000001, password: test123)
python manage.py shell -c "
from apps.riders.models import Rider
if not Rider.objects.filter(phone='+91900000001').exists():
    r = Rider.objects.create_user(username='+91900000001', phone='+91900000001', password='test123',
        first_name='Admin', driving_license_number='DL-TEST-001', aadhar_number='123456789012',
        is_verified=True)
    print('Test rider created:', r.phone)
"
```

### Run

```bash
cd dodoo_delivery_app/backend
.venv\Scripts\activate          # Windows
# or: source .venv/bin/activate  # macOS/Linux

python manage.py runserver 0.0.0.0:8000
```

The backend will be available at: **http://localhost:8000**

Django admin panel: **http://localhost:8000/admin/**

Note: If you (or this repo) change model fields, run `python manage.py makemigrations` before `migrate` to generate migration files.

### Key API Endpoints

| Method   | URL                            | Description                  |
| -------- | ------------------------------ | ---------------------------- |
| GET      | `/`                            | API health / endpoint list   |
| POST     | `/api/riders/signup/`          | Register new rider           |
| POST     | `/api/riders/login/`           | Login with phone + password  |
| POST     | `/api/riders/send-otp/`        | Send OTP (dev OTP: `123456`) |
| POST     | `/api/riders/verify-otp/`      | Verify OTP and get tokens    |
| POST     | `/api/riders/status/`          | Update rider availability    |
| GET      | `/api/orders/rider-dashboard/` | Rider dashboard data         |
| GET/POST | `/api/orders/pricing-config/`  | View/set fare config         |
| POST     | `/api/orders/`                 | Create a new order           |
| POST     | `/api/orders/{id}/accept/`     | Accept an order              |
| POST     | `/api/orders/{id}/status/`     | Update order status          |
| POST     | `/api/tracking/rider/`         | Update live location         |
| GET      | `/api/tracking/health/`        | Tracking health check        |

---

## 2. React Admin Portal

### Setup

```bash
cd dodoo_delivery_app/dodoo-admin

npm install
```

### Run (development)

```bash
npm run dev
```

The admin portal opens at: **http://localhost:5173**

Log in with the test rider credentials: phone `+91900000001`, password `test123`.

### Build for production

```bash
npm run build
npm run preview   # serve the production build locally
```

---

## 3. Flutter Rider App

### Setup

```bash
cd dodoo_delivery_app

flutter pub get
```

### Run on Android emulator

```bash
# Make sure the backend is running first, then:
flutter run
```

The Android emulator reaches the backend at `http://10.0.2.2:8000/api` (auto-detected).

### Run on a physical Android device

**`10.0.2.2` does not work on a real phone — you must use your PC's LAN IP.**

1. Find your PC's IP address:

   ```
   # Windows (Command Prompt)
   ipconfig
   # Look for "IPv4 Address" under your Wi-Fi adapter, e.g. 192.168.1.42
   ```

2. Start Django bound to all interfaces (not just localhost):

   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

3. Make sure your phone and PC are on the **same Wi-Fi network**.

4. Allow port 8000 in Windows Firewall if prompted (or run):

   ```
   netsh advfirewall firewall add rule name="Django 8000" dir=in action=allow protocol=TCP localport=8000
   ```

5. Build/run the app — when it first fails to connect, a dialog opens automatically.  
   Enter: `http://192.168.1.42:8000/api` (use your actual IP from step 1).  
   Tap **Test** to verify, then **Save & Retry**.

   Alternatively, pre-set the URL at build time:

   ```bash
   flutter run --dart-define=DODOO_API_URL=http://192.168.1.42:8000/api
   ```

### Build release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Running the full stack locally

Open three terminals:

**Terminal 1 — Backend:**

```bash
cd dodoo_delivery_app/backend
.venv\Scripts\activate
python manage.py runserver 0.0.0.0:8000
```

**Terminal 2 — Admin portal:**

```bash
cd dodoo_delivery_app/dodoo-admin
npm run dev
```

**Terminal 3 — Flutter app:**

```bash
cd dodoo_delivery_app
flutter run
```

---

## Environment variables

Copy `.env` in `backend/` and adjust as needed:

```env
DJANGO_SECRET_KEY=change-me-in-production
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2,0.0.0.0

# CORS — add the admin portal origin
DJANGO_CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173

# Optional: switch to PostgreSQL
POSTGRES_DB=dodoo_dispatch
POSTGRES_USER=dodoo
POSTGRES_PASSWORD=dodoo_password
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
```

By default the backend uses **SQLite** (no external DB needed for local dev).

---

## Project structure

```
DoDooDeliveryApp/
└── dodoo_delivery_app/
    ├── lib/
    │   └── main.dart               # Flutter rider app (all screens)
    ├── android/                    # Android build config + icons
    ├── pubspec.yaml                # Flutter dependencies
    │
    ├── backend/
    │   ├── apps/
    │   │   ├── riders/             # Auth, profiles, OTP
    │   │   ├── orders/             # Order lifecycle, fare config
    │   │   └── tracking/           # GPS tracking, wallet, earnings
    │   ├── config/
    │   │   ├── settings/base.py
    │   │   └── urls.py
    │   ├── manage.py
    │   └── requirements.txt
    │
    └── dodoo-admin/
        ├── src/main.jsx            # React admin SPA
        ├── vite.config.js
        └── package.json
```
