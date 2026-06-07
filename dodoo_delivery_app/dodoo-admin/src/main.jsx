import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import axios from 'axios';
import './styles.css';

const api = axios.create({
  baseURL: 'http://localhost:8000/api',
  headers: { 'Content-Type': 'application/json' },
});

function formatLocation(location) {
  if (!location) return '-';
  const latitude = Number(location.latitude);
  const longitude = Number(location.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return '-';
  return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`;
}

function mapUrl(location) {
  if (!location) return '#';
  return `https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}`;
}

function formatMoney(value) {
  const amount = Number(value || 0);
  return `Rs ${amount.toFixed(2)}`;
}

function App() {
  const [auth, setAuth] = useState({ phone: '+91900000001', password: 'test123' });
  const [token, setToken] = useState(localStorage.getItem('dodoo_admin_token') || '');
  const [orders, setOrders] = useState([]);
  const [riders, setRiders] = useState([]);
  const [fareConfig, setFareConfig] = useState({ rate_per_km: '8.00', minimum_fare: '50.00' });
  const [message, setMessage] = useState('Backend: http://localhost:8000/api');
  const [loading, setLoading] = useState(false);
  const [order, setOrder] = useState({
    order_number: `DD-${Date.now().toString().slice(-6)}`,
    from_address: 'DoDoo Pickup Hub',
    from_latitude: 17.385,
    from_longitude: 78.4867,
    to_address: 'Customer Doorstep',
    to_latitude: 17.401,
    to_longitude: 78.48,
    items_description: 'Food package',
    distance_in_km: 4.2,
  });

  const authHeaders = useMemo(() => ({ Authorization: `Bearer ${token}` }), [token]);

  useEffect(() => {
    if (token) {
      loadDashboard();
    }
  }, [token]);

  useEffect(() => {
    if (!token) return undefined;
    const timer = window.setInterval(loadDashboard, 8000);
    return () => window.clearInterval(timer);
  }, [token]);

  async function run(action) {
    setLoading(true);
    try {
      await action();
    } catch (error) {
      setMessage(JSON.stringify(error.response?.data || error.message));
    } finally {
      setLoading(false);
    }
  }

  async function login() {
    await run(async () => {
      const response = await api.post('/riders/login/', auth);
      localStorage.setItem('dodoo_admin_token', response.data.access_token);
      setToken(response.data.access_token);
      setMessage(`Logged in as ${response.data.rider.phone}`);
    });
  }

  async function loadOrders() {
    await run(async () => {
      const response = await api.get('/orders/', { headers: authHeaders });
      setOrders(Array.isArray(response.data) ? response.data : response.data.results || []);
      setMessage('Orders loaded');
    });
  }

  async function loadDashboard() {
    await run(async () => {
      const [ordersResponse, ridersResponse] = await Promise.all([
        api.get('/orders/', { headers: authHeaders }),
        api.get('/riders/active/', { headers: authHeaders }),
      ]);
      setOrders(Array.isArray(ordersResponse.data) ? ordersResponse.data : ordersResponse.data.results || []);
      setRiders(Array.isArray(ridersResponse.data) ? ridersResponse.data : ridersResponse.data.results || []);
      setMessage('Dashboard loaded');
    });
  }

  async function loadFareConfig() {
    if (!token) return;
    await run(async () => {
      const response = await api.get('/orders/pricing-config/', { headers: authHeaders });
      setFareConfig(response.data);
      setMessage('Pricing loaded');
    });
  }

  async function saveFareConfig(event) {
    event.preventDefault();
    await run(async () => {
      const response = await api.post('/orders/pricing-config/', fareConfig, { headers: authHeaders });
      setFareConfig(response.data);
      setMessage(`Pricing saved: ${formatMoney(response.data.rate_per_km)} per km, minimum ${formatMoney(response.data.minimum_fare)}`);
    });
  }

  async function createOrder(event) {
    event.preventDefault();
    await run(async () => {
      const response = await api.post('/orders/', order, { headers: authHeaders });
      setOrders((current) => [response.data, ...current]);
      setOrder((current) => ({
        ...current,
        order_number: `DD-${Date.now().toString().slice(-6)}`,
      }));
      setMessage(`Created order ${response.data.order_number}`);
    });
  }

  useEffect(() => {
    if (token) {
      loadFareConfig();
    }
  }, [token]);

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <h1>DoDoo Admin</h1>
          <p>Dispatch operations</p>
        </div>
        <button onClick={loadDashboard} disabled={!token || loading}>Refresh</button>
      </header>

      <section className="grid">
        <form className="panel" onSubmit={(event) => { event.preventDefault(); login(); }}>
          <h2>Backend Login</h2>
          <label>
            Phone
            <input value={auth.phone} onChange={(event) => setAuth({ ...auth, phone: event.target.value })} />
          </label>
          <label>
            Password
            <input type="password" value={auth.password} onChange={(event) => setAuth({ ...auth, password: event.target.value })} />
          </label>
          <button disabled={loading}>Log in</button>
        </form>

        <form className="panel" onSubmit={saveFareConfig}>
          <h2>Fare Configuration</h2>
          <label>
            Per km amount
            <input
              type="number"
              min="0"
              step="0.01"
              value={fareConfig.rate_per_km}
              onChange={(event) => setFareConfig({ ...fareConfig, rate_per_km: event.target.value })}
            />
          </label>
          <label>
            Minimum amount
            <input
              type="number"
              min="0"
              step="0.01"
              value={fareConfig.minimum_fare}
              onChange={(event) => setFareConfig({ ...fareConfig, minimum_fare: event.target.value })}
            />
          </label>
          <button disabled={!token || loading}>Save pricing</button>
        </form>

        <form className="panel" onSubmit={createOrder}>
          <h2>Create Order</h2>
          {Object.entries(order).map(([key, value]) => (
            <label key={key}>
              {key.replaceAll('_', ' ')}
              <input
                value={value}
                onChange={(event) => setOrder({ ...order, [key]: event.target.value })}
              />
            </label>
          ))}
          <button disabled={!token || loading}>Create order</button>
        </form>
      </section>

      <section className="panel">
        <div className="status">{loading ? 'Working...' : message}</div>
        <h2>Active Riders</h2>
        <div className="rider-grid">
          {riders.map((rider) => (
            <article className="rider-card" key={rider.id}>
              <strong>{rider.first_name || 'Rider'} {rider.last_name || ''}</strong>
              <span>{rider.phone}</span>
              <span className={`badge ${rider.current_status}`}>{rider.current_status}</span>
              <small>
                {rider.tracking
                  ? `Location: ${rider.tracking.latitude}, ${rider.tracking.longitude}`
                  : 'No live location yet'}
              </small>
            </article>
          ))}
          {!riders.length && <p className="empty">No riders online or busy.</p>}
        </div>
      </section>

      <section className="panel">
        <h2>Orders</h2>
        <div className="table">
          <div className="row head">
            <span>Order</span>
            <span>Status</span>
            <span>Rider</span>
            <span>Distance</span>
            <span>Fare</span>
            <span>Pickup</span>
            <span>Drop</span>
            <span>Delivery Location</span>
          </div>
          {orders.map((item) => (
            <div className="row" key={item.id}>
              <span>{item.order_number}</span>
              <span>{item.status}</span>
              <span>{item.assigned_rider_phone || 'Unassigned'}</span>
              <span>{item.distance_in_km} km</span>
              <span>
                {formatMoney(item.total_earning)}
                <small>{formatMoney(item.rate_per_km)}/km, min {formatMoney(item.minimum_fare)}</small>
              </span>
              <span>{item.from_address}</span>
              <span>{item.to_address}</span>
              <span>
                {item.delivery_location ? (
                  <a href={mapUrl(item.delivery_location)} target="_blank" rel="noreferrer">
                    {formatLocation(item.delivery_location)}
                    <small>{item.delivery_location.source === 'live' ? 'Live' : 'Last'}</small>
                  </a>
                ) : '-'}
              </span>
            </div>
          ))}
          {!orders.length && <p className="empty">No orders yet.</p>}
        </div>
      </section>
    </main>
  );
}

createRoot(document.getElementById('root')).render(<App />);
