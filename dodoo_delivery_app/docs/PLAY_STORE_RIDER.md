# DoDoo Rider — Google Play Store Submission Guide

Everything needed to publish **DoDoo Rider** on the Google Play Store: listing
copy, permissions justification, Data safety answers, privacy-policy content,
and the build/sign/upload steps.

> Last updated for **v1.3.9 (versionCode 15)**. Update the version line whenever
> you ship a new build.

---

## 1. App identity

| Field | Value |
|-------|-------|
| App name | **DoDoo Rider** |
| Package name (applicationId) | `com.dodoo.delivery.rider` |
| Version name / code | `1.3.9` / `15` |
| Category | **Business** (or *Maps & Navigation*) |
| Default language | English (India) |
| Min Android | 7.0 (API 24) |
| Target Android | API 36 |
| Content rating | Everyone |
| Pricing | Free |
| Contains ads | No |
| In-app purchases | No |

**Backend / tech:** Firebase (Cloud Firestore + Anonymous Auth), Cloudinary
(image hosting), and DoDoo's order/OTP web services. Login is by **phone number
+ OTP** (OTP sent via DoDoo's service — not Firebase Phone Auth).

---

## 2. Store listing copy (copy-paste ready)

### Short description (max 80 chars)
```
Deliver orders, track earnings, and get paid — the DoDoo delivery partner app.
```

### Full description (max 4000 chars)
```
DoDoo Rider is the official delivery-partner app for the DoDoo platform. Accept
delivery orders in your city, navigate to pickup and drop-off, update the order
status in real time, and track your earnings — all from one simple app.

WHY DODOO RIDER
• 0% commission — you keep 100% of every rupee you earn.
• Simple, fast, and built for Indian delivery partners.
• Get paid to your bank account with easy withdrawal requests.

KEY FEATURES
• Phone + OTP login — no passwords to remember.
• Go Online / Offline with a single tap to control when you receive orders.
• Incoming order offers with details: pickup, drop, distance, and your earning.
• Accept or reject offers; one active delivery at a time so you stay focused.
• Live order status flow: Accepted → Picked Up → Delivered.
• Today's earnings, total orders, and rating on your dashboard.
• Earnings wallet with transaction history and bank withdrawal requests.
• Upload your documents (Aadhaar, driving licence) for verification.
• Order history so you can review every delivery you've completed.

HOW IT WORKS
1. Sign in with your phone number and the OTP we send you.
2. Complete your profile and upload your documents for verification.
3. Go Online to start receiving delivery order offers.
4. Accept an order, pick it up, and mark it delivered.
5. Your earning is added to your wallet — withdraw to your bank anytime.

DoDoo Rider is intended for registered DoDoo delivery partners. You'll need an
account approved by the DoDoo team to start delivering.

Questions or support? Reach us from the in-app Help & Support menu.
```

### Other listing assets you must upload
- **App icon:** 512×512 PNG (32-bit, with alpha). Use the DoDoo mascot icon.
- **Feature graphic:** 1024×500 PNG/JPG (no alpha).
- **Phone screenshots:** 2–8 images, min 1080px on the long edge. Suggested:
  1) Sign-in / "0% commission" screen, 2) Dashboard (Online + stat cards),
  3) Incoming order offer, 4) Active delivery / status flow, 5) Earnings wallet,
  6) Profile & document verification.
- **Contact email** + a **Privacy Policy URL** (see §5 — mandatory).

---

## 3. Permissions — and the ONE thing to fix before submitting

Current permissions declared in `android/app/src/main/AndroidManifest.xml`:

| Permission | Used for | Play notes |
|-----------|----------|-----------|
| `INTERNET` | All network calls (Firestore, APIs) | Standard, no disclosure needed |
| `ACCESS_COARSE_LOCATION` | Pick the rider's nearest city; delivery location | Foreground only |
| `ACCESS_FINE_LOCATION` | Precise pickup/drop tracking during a delivery | Foreground only |
| `POST_NOTIFICATIONS` | New-order alerts | Standard on Android 13+ |
| `WAKE_LOCK` | Keep alerts working | Standard |
| ⚠️ `ACCESS_BACKGROUND_LOCATION` | **Declared but NOT used** | **Triggers strict review — remove** |
| ⚠️ `FOREGROUND_SERVICE` | **Declared, no service exists** | Remove unless you add one |
| ⚠️ `FOREGROUND_SERVICE_LOCATION` | **Declared, no service exists** | Remove unless you add one |

> ### 🔴 Action required before first submission
> The app requests **background location** and **foreground-service** permissions
> but the code never uses them — location is only read on-demand
> (`Geolocator.getCurrentPosition` in `lib/core/api/rider_firestore_api.dart`),
> there is no background service, and no `getPositionStream`. Shipping
> `ACCESS_BACKGROUND_LOCATION` forces Google's **background-location review**
> (written justification + a demo video + weeks of delay) and is a common
> rejection reason.
>
> **Recommendation:** remove these three lines from the manifest until a real
> background-tracking feature exists:
> ```xml
> <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
> <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
> <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
> ```
> Foreground fine/coarse location is enough for the current feature set and needs
> only the standard in-app location disclosure (not the special review).

---

## 4. Data safety form (Play Console answers)

The app collects the following. Answer the Data safety questionnaire accordingly.

| Data type | Collected | Purpose | Shared? | Optional? |
|-----------|-----------|---------|---------|-----------|
| Phone number | Yes | Account/identity, login (OTP) | No | Required |
| Name | Yes | Account, delivery assignment | No | Required |
| Address | Yes | City/area matching | No | Optional |
| Approx. + precise location | Yes | Delivery pickup/drop, nearest-city | No | Required (in-use) |
| Photos (profile) | Yes | Profile identity | No | Optional |
| Government ID (Aadhaar, licence) | Yes | Partner verification (KYC) | No | Required to deliver |
| Bank account / IFSC | Yes | Earnings payout | No | Optional |
| App activity (orders, earnings) | Yes | Core app function | No | Required |

Additional answers:
- **Is data encrypted in transit?** Yes (HTTPS/Firestore TLS).
- **Can users request deletion?** Provide a deletion path (in-app or email) — see §5.
- **Data sold?** No.
- Images are stored on **Cloudinary**; order/profile data in **Cloud Firestore**.

> ⚠️ Because you collect **government IDs and bank details**, your Data safety
> section and privacy policy must explicitly cover them, and you should have a
> clear KYC/data-retention statement.

---

## 5. Privacy policy (mandatory)

Google **requires a hosted privacy-policy URL** for any app that handles personal
or sensitive data. Host a page (e.g. `https://dodoo.in/privacy-rider`) covering:

- Who you are (DoDoo) and contact email.
- What you collect: phone, name, address, location, profile photo, Aadhaar &
  driving licence images, bank account/IFSC, order & earnings activity.
- Why: partner onboarding/verification (KYC), assigning & tracking deliveries,
  paying earnings, fraud prevention, support.
- Where it's stored: Google Firebase (Firestore) and Cloudinary (images);
  processed by DoDoo's order services.
- Sharing: not sold; shared only as needed to operate deliveries and payouts.
- Security: TLS in transit, access-controlled Firestore rules.
- Retention & deletion: how long you keep KYC data and **how a partner requests
  account/data deletion** (required by Play's Data deletion policy).
- Users' rights and how to contact you.

---

## 6. Build, sign & upload

Play Store requires an **App Bundle (.aab)**, release-signed (a debug-signed or
unsigned build is rejected).

### 6.1 One-time: create a release keystore
```bash
keytool -genkey -v -keystore dodoo-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias dodoo
```
> 🔐 **Back up `dodoo-release.jks` and its passwords somewhere safe forever.**
> If you lose it you can never update the app on Play (you'd have to publish a
> brand-new listing). Do **not** commit it to git.

Create `android/key.properties` (also git-ignored):
```properties
storeFile=../dodoo-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=dodoo
keyPassword=YOUR_KEY_PASSWORD
```
The release `signingConfig` in `android/app/build.gradle.kts` already picks this
file up automatically when it exists.

### 6.2 Build the release App Bundle
```bash
flutter clean          # always clean first — avoids stale compiled Dart
flutter build appbundle --release --flavor rider -t lib/main.dart
# output: build/app/outputs/bundle/riderRelease/app-rider-release.aab
```

> ⚠️ **Always `flutter clean` before a release build.** We have hit incremental
> builds that shipped stale code (an old version string compiled into an
> otherwise-current build). A clean build is the only reliable cure. Verify after
> building:
> ```bash
> flutter build apk --release --flavor rider -t lib/main.dart --split-per-abi --target-platform android-arm64
> unzip -p build/app/outputs/flutter-apk/app-arm64-v8a-rider-release.apk \
>   lib/arm64-v8a/libapp.so | grep -a -o "v1\.3\.[0-9]" | sort -u   # should print current version
> ```

### 6.3 Upload
1. Play Console → **Create app** → fill name, language, app/game, free.
2. Complete: App content (privacy policy, ads, data safety, target audience,
   content rating), then **Production → Create release**.
3. Upload the `.aab`, add release notes, roll out.
4. Google manages the signing key (Play App Signing) — keep your upload key safe.

---

## 7. Pre-launch checklist

- [ ] Remove unused background-location / foreground-service permissions (§3).
- [ ] Bump `version:` in `pubspec.yaml` and the version string in
      `lib/features/home/presentation/screens/profile_tab.dart`.
- [ ] `flutter clean` + build `.aab`; verify the version string inside the build.
- [ ] Release keystore created and **backed up**; `key.properties` in place.
- [ ] Privacy-policy URL live and linked in Play Console.
- [ ] Data safety form completed (phone, location, ID, bank).
- [ ] Icon 512×512, feature graphic 1024×500, 2–8 screenshots.
- [ ] Test the signed release build on a real device (login → go online → accept
      → deliver → withdraw).
- [ ] Confirm `google-services.json` includes `com.dodoo.delivery.rider`.
- [ ] Admin default password (`dodoo@123`) is not shipped in a public build.
```
