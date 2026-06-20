import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer


class OrderConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for real-time order events.

    Connect:  ws://host/ws/orders/?token=<JWT>
    Groups:
      all_riders     → new_order, order_accepted broadcasts
      rider_<id>     → order_status_changed for this specific rider
    """

    async def connect(self):
        user = await self._authenticate()
        if user is None:
            await self.close(code=4001)
            return

        self.rider = user
        self.rider_group = f"rider_{self.rider.pk}"

        await self.channel_layer.group_add("all_riders", self.channel_name)
        await self.channel_layer.group_add(self.rider_group, self.channel_name)
        await self.accept()
        await self.send(json.dumps({"type": "connected"}))

    async def disconnect(self, code):
        if hasattr(self, "rider"):
            await self.channel_layer.group_discard("all_riders", self.channel_name)
            await self.channel_layer.group_discard(self.rider_group, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        pass  # riders only receive

    # ── Group event handlers ──────────────────────────────────────────────────

    async def new_order(self, event):
        await self.send(json.dumps({"type": "new_order", "order": event["order"]}))

    async def order_accepted(self, event):
        await self.send(json.dumps({
            "type": "order_accepted",
            "order_id": event["order_id"],
            "rider_id": event.get("rider_id"),
        }))

    async def order_status_changed(self, event):
        await self.send(json.dumps({
            "type": "order_status_changed",
            "order_id": event["order_id"],
            "status": event["status"],
        }))

    # ── JWT auth via query-string ─────────────────────────────────────────────

    async def _authenticate(self):
        try:
            qs = self.scope.get("query_string", b"").decode()
            params = {
                k: v
                for k, v in (p.split("=", 1) for p in qs.split("&") if "=" in p)
            }
            token_str = params.get("token", "")
            if not token_str:
                return None
            from rest_framework_simplejwt.tokens import AccessToken
            token = AccessToken(token_str)
            return await self._get_rider(token.get("user_id"))
        except Exception:
            return None

    @database_sync_to_async
    def _get_rider(self, user_id):
        from apps.riders.models import Rider
        try:
            return Rider.objects.get(pk=user_id)
        except Rider.DoesNotExist:
            return None
