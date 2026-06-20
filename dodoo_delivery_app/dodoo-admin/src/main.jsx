import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import axios from "axios";
import "./styles.css";

// ── Supabase config (same project as the Flutter app) ──────────────────────
const SUPABASE_URL = "https://aijlvspbunaopspcslcg.supabase.co";
const SUPABASE_ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpamx2c3BidW5hb3BzcGNzbGNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzNjg3OTYsImV4cCI6MjA5Njk0NDc5Nn0.JvyQFcd39WuwlhqWVU4PTzufcXLU5Lp8pc8IlfCA98c";

// Hardcoded admin gate — matches the Flutter admin portal.
const ADMIN_USER = "admin";
const ADMIN_PASS = "dodoo@123";

const sb = axios.create({
  baseURL: `${SUPABASE_URL}/rest/v1`,
  headers: {
    apikey: SUPABASE_ANON,
    Authorization: `Bearer ${SUPABASE_ANON}`,
    "Content-Type": "application/json",
  },
});

function formatMoney(value) {
  const amount = Number(value || 0);
  return `Rs ${amount.toFixed(2)}`;
}

function formatTime(ts) {
  if (!ts) return "-";
  return new Date(ts).toLocaleString("en-IN", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

function App() {
  const [auth, setAuth] = useState({ username: "admin", password: "" });
  const [token, setToken] = useState(
    localStorage.getItem("dodoo_admin_token") || "",
  );
  const [orders, setOrders] = useState([]);
  const [riders, setRiders] = useState([]); // online/busy riders + tracking
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [tick, setTick] = useState(0);
  const [order, setOrder] = useState({
    from_address: "MG Road, Bengaluru",
    from_latitude: 12.9716,
    from_longitude: 77.5946,
    to_address: "Koramangala, Bengaluru",
    to_latitude: 12.9352,
    to_longitude: 77.6245,
    total_earning: 85,
    customer_name: "Test Customer",
    customer_phone: "9876543210",
    items_description: "1x Food package",
  });

  const secondsAgo = useMemo(
    () => (lastUpdated ? Math.floor((Date.now() - lastUpdated) / 1000) : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [tick, lastUpdated],
  );

  useEffect(() => {
    if (token) loadDashboard();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    if (!token) return undefined;
    const timer = window.setInterval(loadDashboard, 8000);
    return () => window.clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    const timer = window.setInterval(() => setTick((t) => t + 1), 1000);
    return () => window.clearInterval(timer);
  }, []);

  async function run(fn) {
    setLoading(true);
    try {
      await fn();
    } catch (error) {
      setMessage(JSON.stringify(error.response?.data || error.message));
    } finally {
      setLoading(false);
    }
  }

  function login() {
    if (
      auth.username.trim().toLowerCase() !== ADMIN_USER ||
      auth.password !== ADMIN_PASS
    ) {
      setMessage("Invalid credentials. Use admin / dodoo@123");
      return;
    }
    localStorage.setItem("dodoo_admin_token", "SUPABASE_ADMIN");
    setToken("SUPABASE_ADMIN");
    setMessage("");
  }

  function logout() {
    localStorage.removeItem("dodoo_admin_token");
    setToken("");
    setOrders([]);
    setRiders([]);
    setMessage("");
    setLastUpdated(null);
  }

  async function loadDashboard() {
    await run(async () => {
      const [ordersRes, ridersRes, trackingRes] = await Promise.all([
        sb.get("/orders?select=*&order=created_at.desc&limit=100"),
        sb.get(
          "/riders?select=id,first_name,last_name,phone,current_status&current_status=in.(online,busy)",
        ),
        sb.get(
          "/rider_tracking?select=rider_id,latitude,longitude,is_tracking&is_tracking=eq.true",
        ),
      ]);

      const trackingByRider = {};
      for (const t of trackingRes.data || []) {
        trackingByRider[t.rider_id] = t;
      }
      const mergedRiders = (ridersRes.data || []).map((r) => ({
        ...r,
        tracking: trackingByRider[r.id] || null,
      }));

      setOrders(ordersRes.data || []);
      setRiders(mergedRiders);
      setLastUpdated(Date.now());
      setMessage("");
    });
  }

  async function createOrder(event) {
    event.preventDefault();
    await run(async () => {
      const distanceKm =
        Math.round(
          haversineKm(
            Number(order.from_latitude),
            Number(order.from_longitude),
            Number(order.to_latitude),
            Number(order.to_longitude),
          ) * 100,
        ) / 100;

      const fare = Number(order.total_earning) || 0;

      const payload = {
        order_number: `DD-${Date.now().toString().slice(-6)}`,
        status: "pending", // unassigned — broadcast to all riders
        from_address: order.from_address,
        from_latitude: Number(order.from_latitude),
        from_longitude: Number(order.from_longitude),
        to_address: order.to_address,
        to_latitude: Number(order.to_latitude),
        to_longitude: Number(order.to_longitude),
        distance_in_km: distanceKm,
        estimated_time_minutes: Math.min(180, Math.max(5, Math.round(distanceKm * 4))),
        total_earning: fare,
        minimum_fare: fare,
        customer_name: order.customer_name,
        customer_phone: order.customer_phone,
        items_description: order.items_description,
        status_updated_at: new Date().toISOString(),
      };

      // 1. Create the order (pending, unassigned).
      const res = await sb.post("/orders", payload, {
        headers: { Prefer: "return=representation" },
      });
      const created = Array.isArray(res.data) ? res.data[0] : res.data;

      // 2. Broadcast to all approved riders via order_offers. First to accept
      //    wins; the order then flips to accepted and disappears for the rest.
      const ridersRes = await sb.get(
        "/riders?select=id&account_status=eq.approved",
      );
      const riderIds = (ridersRes.data || []).map((r) => r.id).filter(Boolean);
      if (riderIds.length) {
        const nowIso = new Date().toISOString();
        const offers = riderIds.map((rid) => ({
          order_id: created.id,
          rider_id: rid,
          is_accepted: false,
          is_rejected: false,
          notified_at: nowIso,
        }));
        await sb.post("/order_offers", offers);
      }

      setOrders((current) => [created, ...current]);
      setMessage(
        `Order ${created.order_number} broadcast to ${riderIds.length} rider(s) — ${created.distance_in_km} km.`,
      );
    });
  }

  // ── Login page ──────────────────────────────────────────────────────────
  if (!token) {
    return (
      <main className="login-page">
        <form
          className="login-card"
          onSubmit={(e) => {
            e.preventDefault();
            login();
          }}
        >
          <div className="login-brand">
            <h1>DoDoo</h1>
            <p>Admin Portal</p>
          </div>
          <label>
            Username
            <input
              type="text"
              autoComplete="username"
              value={auth.username}
              onChange={(e) => setAuth({ ...auth, username: e.target.value })}
              placeholder="admin"
            />
          </label>
          <label>
            Password
            <input
              type="password"
              autoComplete="current-password"
              value={auth.password}
              onChange={(e) => setAuth({ ...auth, password: e.target.value })}
              placeholder="dodoo@123"
            />
          </label>
          {message && <p className="login-error">{message}</p>}
          <button type="submit" disabled={loading} style={{ marginTop: 8, width: "100%" }}>
            {loading ? "Logging in…" : "Log in"}
          </button>
        </form>
      </main>
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <h1>DoDoo Admin</h1>
          <p>Dispatch operations · Supabase</p>
        </div>
        <div className="topbar-right">
          {loading && <span className="dim">Working…</span>}
          {!loading && secondsAgo !== null && (
            <span className="dim">Updated {secondsAgo}s ago · auto-refresh 8s</span>
          )}
          <button onClick={loadDashboard} disabled={loading}>
            Refresh
          </button>
          <button className="btn-secondary" onClick={logout}>
            Log out
          </button>
        </div>
      </header>

      {message && <p className="dash-message">{message}</p>}

      <section className="grid-2col">
        <form className="panel" onSubmit={createOrder}>
          <h2>Create Order</h2>
          {Object.entries(order).map(([key, value]) => (
            <label key={key}>
              {key.replaceAll("_", " ")}
              <input
                value={value}
                onChange={(e) => setOrder({ ...order, [key]: e.target.value })}
              />
            </label>
          ))}
          <p className="field-hint">
            Distance auto-calculated from coordinates. The order is{" "}
            <strong>broadcast to all approved riders</strong> — the first to
            accept gets it, and it disappears for everyone else. The customer
            phone stays private (riders call support instead).
          </p>
          <button disabled={loading}>Broadcast order</button>
        </form>

        <section className="panel">
          <h2>
            Active Riders
            <small className="section-sub"> (online / busy)</small>
          </h2>
          <div className="rider-grid">
            {riders.map((rider) => (
              <article className="rider-card" key={rider.id}>
                <strong>
                  {rider.first_name || "Rider"} {rider.last_name || ""}
                </strong>
                <span>{rider.phone}</span>
                <span className={`badge ${rider.current_status}`}>
                  {rider.current_status}
                </span>
                <small>
                  {rider.tracking
                    ? `📍 ${Number(rider.tracking.latitude).toFixed(5)}, ${Number(
                        rider.tracking.longitude,
                      ).toFixed(5)}`
                    : "No live location"}
                </small>
              </article>
            ))}
            {!riders.length && <p className="empty">No riders online or busy.</p>}
          </div>
        </section>
      </section>

      <section className="panel">
        <h2>
          All Orders
          <small className="section-sub">
            {orders.length} total · newest first · auto-refreshes every 8s
          </small>
        </h2>
        <div className="table">
          <div className="row head">
            <span>Order</span>
            <span>Status</span>
            <span>Rider</span>
            <span>Distance</span>
            <span>Fare</span>
            <span>Pickup</span>
            <span>Drop</span>
            <span>Created</span>
          </div>
          {orders.map((item) => (
            <div className="row" key={item.id}>
              <span>{item.order_number}</span>
              <span>
                <span className={`badge ${item.status}`}>
                  {String(item.status || "").replace(/_/g, " ")}
                </span>
              </span>
              <span>
                {item.assigned_rider_id ? (
                  <span title={item.assigned_rider_id}>Assigned</span>
                ) : (
                  <span className="dim">Unassigned</span>
                )}
              </span>
              <span>{item.distance_in_km} km</span>
              <span>{formatMoney(item.total_earning)}</span>
              <span>{item.from_address}</span>
              <span>{item.to_address}</span>
              <span>{formatTime(item.created_at)}</span>
            </div>
          ))}
          {!orders.length && <p className="empty">No orders yet. Create one above.</p>}
        </div>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
