import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import axios from "axios";
import "./styles.css";

const api = axios.create({
  baseURL: "http://localhost:8000/api",
  headers: { "Content-Type": "application/json" },
});

function formatLocation(location) {
  if (!location) return "-";
  const latitude = Number(location.latitude);
  const longitude = Number(location.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return "-";
  return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`;
}

function mapUrl(location) {
  if (!location) return "#";
  return `https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}`;
}

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
  const [auth, setAuth] = useState({
    phone: "+91900000012",
    password: "test123",
  });
  const [token, setToken] = useState(
    localStorage.getItem("dodoo_admin_token") || "",
  );
  const [orders, setOrders] = useState([]);
  const [riders, setRiders] = useState([]);
  const [fareConfig, setFareConfig] = useState({
    rate_per_km: "8.00",
    minimum_fare: "50.00",
  });
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [tick, setTick] = useState(0);
  const [order, setOrder] = useState({
    order_number: `DD-${Date.now().toString().slice(-6)}`,
    from_address: "Noida Sector 50",
    from_latitude: 28.5492,
    from_longitude: 77.3302,
    to_address: "Customer Location",
    to_latitude: 28.59,
    to_longitude: 77.35,
    items_description: "Food package",
  });

  const authHeaders = useMemo(
    () => ({ Authorization: `Bearer ${token}` }),
    [token],
  );
  const secondsAgo = useMemo(
    () => (lastUpdated ? Math.floor((Date.now() - lastUpdated) / 1000) : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [tick, lastUpdated],
  );

  useEffect(() => {
    if (token) loadDashboard();
  }, [token]);

  useEffect(() => {
    if (!token) return undefined;
    const timer = window.setInterval(loadDashboard, 8000);
    return () => window.clearInterval(timer);
  }, [token]);

  useEffect(() => {
    const timer = window.setInterval(() => setTick((t) => t + 1), 1000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (token) loadFareConfig();
  }, [token]);

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

  async function login() {
    await run(async () => {
      const response = await api.post("/riders/login/", auth);
      localStorage.setItem("dodoo_admin_token", response.data.access_token);
      setToken(response.data.access_token);
      setMessage("");
    });
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
      const [ordersRes, ridersRes] = await Promise.all([
        api.get("/orders/", { headers: authHeaders }),
        api.get("/riders/active/", { headers: authHeaders }),
      ]);
      const rawOrders = Array.isArray(ordersRes.data)
        ? ordersRes.data
        : ordersRes.data.results || [];
      rawOrders.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
      setOrders(rawOrders);
      setRiders(
        Array.isArray(ridersRes.data)
          ? ridersRes.data
          : ridersRes.data.results || [],
      );
      setLastUpdated(Date.now());
      setMessage("");
    });
  }

  async function loadFareConfig() {
    if (!token) return;
    await run(async () => {
      const response = await api.get("/orders/pricing-config/", {
        headers: authHeaders,
      });
      setFareConfig(response.data);
    });
  }

  async function saveFareConfig(event) {
    event.preventDefault();
    await run(async () => {
      const response = await api.post("/orders/pricing-config/", fareConfig, {
        headers: authHeaders,
      });
      setFareConfig(response.data);
      setMessage(
        `Pricing saved: ${formatMoney(response.data.rate_per_km)}/km, min ${formatMoney(response.data.minimum_fare)}`,
      );
    });
  }

  async function createOrder(event) {
    event.preventDefault();
    await run(async () => {
      const distanceKm = haversineKm(
        Number(order.from_latitude),
        Number(order.from_longitude),
        Number(order.to_latitude),
        Number(order.to_longitude),
      );
      const payload = {
        ...order,
        distance_in_km: Math.round(distanceKm * 100) / 100,
      };
      const response = await api.post("/orders/", payload, {
        headers: authHeaders,
      });
      setOrders((current) => [response.data, ...current]);
      setOrder((current) => ({
        ...current,
        order_number: `DD-${Date.now().toString().slice(-6)}`,
      }));
      setMessage(
        `Order ${response.data.order_number} created — ${response.data.distance_in_km} km`,
      );
    });
  }

  // ── Login page (shown when not authenticated) ───────────────────────────
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
            Phone
            <input
              type="tel"
              autoComplete="username"
              value={auth.phone}
              onChange={(e) => setAuth({ ...auth, phone: e.target.value })}
              placeholder="+91900000012"
            />
          </label>
          <label>
            Password
            <input
              type="password"
              autoComplete="current-password"
              value={auth.password}
              onChange={(e) => setAuth({ ...auth, password: e.target.value })}
              placeholder="Password"
            />
          </label>
          {message && <p className="login-error">{message}</p>}
          <button
            type="submit"
            disabled={loading}
            style={{ marginTop: 8, width: "100%" }}
          >
            {loading ? "Logging in…" : "Log in"}
          </button>
        </form>
      </main>
    );
  }

  // ── Dashboard (shown when authenticated) ────────────────────────────────
  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <h1>DoDoo Admin</h1>
          <p>Dispatch operations</p>
        </div>
        <div className="topbar-right">
          {loading && <span className="dim">Working…</span>}
          {!loading && secondsAgo !== null && (
            <span className="dim">
              Updated {secondsAgo}s ago · auto-refresh 8s
            </span>
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
        <form className="panel" onSubmit={saveFareConfig}>
          <h2>Fare Configuration</h2>
          <label>
            Per km amount (Rs)
            <input
              type="number"
              min="0"
              step="0.01"
              value={fareConfig.rate_per_km}
              onChange={(e) =>
                setFareConfig({ ...fareConfig, rate_per_km: e.target.value })
              }
            />
          </label>
          <label>
            Minimum fare (Rs)
            <input
              type="number"
              min="0"
              step="0.01"
              value={fareConfig.minimum_fare}
              onChange={(e) =>
                setFareConfig({ ...fareConfig, minimum_fare: e.target.value })
              }
            />
          </label>
          <button disabled={loading}>Save pricing</button>
        </form>

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
            Distance is auto-calculated from coordinates on the backend.
          </p>
          <button disabled={loading}>Create order</button>
        </form>
      </section>

      <section className="panel">
        <h2>
          Active Riders
          <small className="section-sub">
            (busy riders shown only if delivery destination is within 15 km)
          </small>
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
                  ? `📍 ${rider.tracking.latitude}, ${rider.tracking.longitude}`
                  : "No live location"}
              </small>
            </article>
          ))}
          {!riders.length && <p className="empty">No riders online or busy.</p>}
        </div>
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
            {/*<span>Delivery Location</span>*/}
            <span>Created</span>
          </div>
          {orders.map((item) => (
            <div className="row" key={item.id}>
              <span>{item.order_number}</span>
              <span>
                <span className={`badge ${item.status}`}>
                  {item.status.replace(/_/g, " ")}
                </span>
              </span>
              <span>
                {item.assigned_rider_phone || (
                  <span className="dim">Unassigned</span>
                )}
              </span>
              <span>{item.distance_in_km} km</span>
              <span>
                {formatMoney(item.total_earning)}
                <small>
                  {formatMoney(item.rate_per_km)}/km · min{" "}
                  {formatMoney(item.minimum_fare)}
                </small>
              </span>
              <span>{item.from_address}</span>
              <span>{item.to_address}</span>
              {/* <span>
                {item.delivery_location ? (
                  <a
                    href={mapUrl(item.delivery_location)}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {formatLocation(item.delivery_location)}
                    <small>
                      {item.delivery_location.source === "live"
                        ? "🟢 Live"
                        : "⚪ Last known"}
                    </small>
                  </a>
                ) : (
                  <span className="dim">—</span>
                )}
              </span> */}
              <span>{formatTime(item.created_at)}</span>
            </div>
          ))}
          {!orders.length && (
            <p className="empty">No orders yet. Create one above.</p>
          )}
        </div>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
