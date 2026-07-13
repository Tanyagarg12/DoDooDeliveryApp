# DoDoo Rider — Database (Firestore) Testing Guide

How the rider app reads its data, and **exactly how to add or delete test records
so the change shows up in the app**. Use this to create fake orders/offers, watch
the rider accept/deliver them, and clean up afterwards.

---

## 0. How reflection works (read this first)

The rider app talks to **Cloud Firestore** (Firebase project **`dodoo-admin-refresh`**).

It does **not** use live streaming for the dashboard. Instead it **polls every
10 seconds** and on pull-to-refresh:

- `lib/features/home/presentation/controllers/rider_dashboard_controller.dart`
  runs `refresh()` on a `Timer.periodic(Duration(seconds: 10))`.
- Pull down on the dashboard to force an immediate refresh.

**So any add/edit/delete you make in Firestore appears in the app within ~10
seconds** (or instantly if you pull-to-refresh). If something doesn't show, wait
10s or pull to refresh — you don't need to restart the app.

### Where to make changes
- **Firebase Console → Firestore Database** (easiest):
  https://console.firebase.google.com/project/dodoo-admin-refresh/firestore
- Or the **DoDoo Admin app** (it writes the same collections).

---

## 1. Collections the rider app uses

| Collection | Doc ID | What it is |
|-----------|--------|-----------|
| `riders` | rider's UID | The rider's profile, status, wallet, rating, documents |
| `orders` | order ID | Every order; the rider sees ones assigned to them or open/pending |
| `order_offers` | offer ID | A specific order offered to a specific rider |
| `rider_tracking` | — | GPS pings sent during a delivery |
| `withdrawal_requests` | — | Payout requests the rider makes |
| `wallet_transactions` | — | Wallet ledger entries |
| `app_settings` | setting key | Admin config: per-km rate, min charge, PDP charge, etc. |

### Finding a rider's UID (you need this to target them)
Open `riders`, find the doc whose `phone` matches the test rider's number — the
**document ID is the UID**. You'll paste this UID into `assigned_rider_id` /
`rider_id` fields below.

---

## 2. Order document — the fields that matter

The rider app reads these fields off an `orders/{orderId}` document:

| Field | Type | Meaning |
|-------|------|---------|
| `status` | string | `pending` → available/offer; `accepted`, `picked_up`, `in_transit`, `reached` → active; `completed`, `cancelled` → history |
| `assigned_rider_id` | string | UID of the rider handling it. **Empty = unassigned/open** |
| `rider_id` | string | Same UID (set on accept) |
| `order_number` | string | The DoDoo order id (city-prefixed, e.g. `ATP_STOR2026...`) |
| `order_type` | string | `store` or PDP (pick-drop) |
| `total_earning` | number | What the rider earns (₹) — shown on the card |
| `created_at` | timestamp | Sort key (dashboard orders by this) |
| `completed_at` | timestamp | Set on completion; drives "today's earnings" |
| `distance_in_km`, `per_km_rate`, `base_fare`, `min_fare` | number | Fare breakdown |
| pickup / drop / customer / items fields | various | Shown in order detail |

> The dashboard's earnings totals only count orders with `status: completed` and a
> `completed_at` inside today/this week/this month.

### Status meaning in the app
```
pending    → shows as an incoming OFFER (if unassigned & not rejected by this rider)
accepted   → active delivery, step "Accepted"
picked_up  → active delivery, step "Picked Up"   (in_transit / reached also map here)
completed  → moves to History; earning credited to wallet
cancelled  → moves to History
```

---

## 3. Recipe A — make a test order APPEAR as an incoming offer

This is the simplest, most reliable way to get an order in front of a rider.

1. Firebase Console → `orders` → **Add document** (Auto-ID).
2. Add these fields:
   | Field | Type | Value |
   |-------|------|-------|
   | `status` | string | `pending` |
   | `assigned_rider_id` | string | *(leave empty `""`)* |
   | `order_number` | string | `TEST_0001` |
   | `order_type` | string | `store` |
   | `total_earning` | number | `80` |
   | `created_at` | timestamp | *(now — click the clock)* |
   | `pickup_address` | string | `Test Restaurant, Anantapur` |
   | `drop_address` | string | `Test Customer, Anantapur` |
3. Save. Within **10 seconds** (or pull-to-refresh) the order appears in the
   rider's **Incoming Offers** on the dashboard — as long as the rider is
   **Online** and hasn't rejected it.

> Because the app surfaces *any* unassigned `pending` order (see `dashboard()` in
> `firestore_service.dart`), you do **not** need to create an `order_offers` doc
> for it to show up. Do §Recipe B only if you want to target one specific rider.

### Recipe B — target ONE specific rider (optional)
Also add a doc to `order_offers`:
| Field | Type | Value |
|-------|------|-------|
| `order_id` | string | *(the orders doc ID from Recipe A)* |
| `rider_id` | string | *(the target rider's UID)* |
| `is_accepted` | boolean | `false` |
| `is_rejected` | boolean | `false` |
| `created_at` | timestamp | now |

---

## 4. Recipe C — watch the full lifecycle

1. Create the order (Recipe A). → appears as an offer.
2. In the app, tap **Accept**. The app sets `assigned_rider_id`, `rider_id`, and
   `status: accepted`, and it moves to **Active Order**.
3. In the app, advance status **Accepted → Picked Up → Delivered**. On
   "Delivered" the app sets `status: completed`, `completed_at`, and **credits
   `total_earning` to the rider's wallet** (`wallet_balance` on the `riders` doc,
   plus a `wallet_transactions` entry).
4. The order moves to **History**, and **Today's Earn** on the dashboard goes up
   by the earning amount.

> You can also drive steps 2–3 from Firestore by editing the order's `status`
> field directly — the app reflects it on the next poll.

---

## 5. Recipe D — DELETE a test order (clean up)

To remove a test order so it disappears from the app:

1. Delete the `orders/{orderId}` document.
2. If you created one, delete the matching `order_offers` doc too.
3. Within ~10s / on refresh, it's gone from the app.

> **Removing the credited earning:** deleting a *completed* order does **not**
> automatically subtract the money already added to the wallet. To fully undo a
> test delivery, also edit the rider's `riders/{uid}.wallet_balance` back down and
> delete the related `wallet_transactions` entry.

---

## 6. Other quick tests

| I want to… | Do this in Firestore | Reflects |
|------------|----------------------|----------|
| Force the rider Online/Offline | `riders/{uid}.current_status` = `online` / `offline` | next poll |
| Change the rider's rating | `riders/{uid}.rating` = e.g. `4.7` | next poll |
| Set wallet balance | `riders/{uid}.wallet_balance` = number | next poll |
| Mark documents verified | `riders/{uid}.is_document_verified` = `true` | next poll |
| Change delivery pricing | `app_settings` → the relevant key's `value` (e.g. `price_per_km_ATP`, `min_delivery_charge`, `pickdrop_charge`) | applies to new/ongoing orders |
| Make an order "unassigned" again | clear `assigned_rider_id` and set `status: pending` | next poll (re-appears as offer) |

---

## 7. Gotchas

- **Rider must be Online** to see offers on the dashboard.
- An order the rider **rejected** is filtered out for that rider (an
  `order_offers` doc with `is_rejected: true`). Delete that offer doc to make it
  offer-able again.
- Only orders with `status: pending` **and** empty `assigned_rider_id` show as
  offers. If you set a status the app doesn't recognise, it won't appear.
- Earnings totals need `status: completed` **and** a `completed_at` timestamp.
- Field **names and types matter** — `total_earning` must be a *number*, not a
  string; `is_accepted`/`is_rejected` must be *booleans*; timestamps must be
  Firestore *timestamps*, not strings.
- Changes reflect on the **10-second poll** — wait or pull-to-refresh; no app
  restart needed.
```
