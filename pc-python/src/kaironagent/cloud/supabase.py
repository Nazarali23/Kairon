"""
Supabase REST İstemcisi
- pc_commands tablosundan bekleyen komutları çeker ve atomik olarak sahiplenir (claim).
- pc_agent_state tablosuna düzenli kalp atışı (heartbeat) gönderir.
- robot_state.pending_say alanına metin yazarak Kairon robotunu konuşturur.
"""

import socket
import logging
from uuid import UUID
from datetime import datetime, timezone
from typing import Optional, List
import httpx
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from .models import Command, CommandStatus

logger = logging.getLogger("kaironagent.supabase")

class SupabaseClient:
    def __init__(self, supabase_url: str, service_role_key: str):
        self.base_url = supabase_url.rstrip("/")
        self.service_role_key = service_role_key
        self.hostname = socket.gethostname()

        self.headers = {
            "apikey": self.service_role_key,
            "Authorization": f"Bearer {self.service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            base_url=self.base_url,
            headers=self.headers,
            timeout=8.0
        )

    @retry(
        reraise=True,
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=4),
        retry=retry_if_exception_type((httpx.ConnectError, httpx.TimeoutException))
    )
    async def fetch_pending(self, limit: int = 5) -> List[Command]:
        """Bekleyen (pending) komutları çeker."""
        url = f"/rest/v1/pc_commands?status=eq.pending&order=created_at.asc&limit={limit}"
        async with self._client() as client:
            resp = await client.get(url)
            resp.raise_for_status()
            data = resp.json()
            return [Command.model_validate(item) for item in data]

    async def claim(self, cmd_id: UUID) -> bool:
        """Komutu atomik olarak 'received' durumuna alır ve PC adını kaydeder."""
        now_str = datetime.now(timezone.utc).isoformat()
        payload = {
            "status": CommandStatus.RECEIVED.value,
            "claimed_by": self.hostname,
            "claimed_at": now_str,
            "updated_at": now_str
        }
        url = f"/rest/v1/pc_commands?id=eq.{cmd_id}&status=eq.pending"

        async with self._client() as client:
            resp = await client.patch(url, json=payload)
            if resp.status_code == 200:
                data = resp.json()
                return len(data) > 0
            return False

    async def update_command(
        self,
        cmd_id: UUID,
        status: CommandStatus,
        plan: Optional[dict] = None,
        result: Optional[str] = None,
        error: Optional[str] = None
    ) -> bool:
        """Komutun durumunu ve sonucunu günceller."""
        now_str = datetime.now(timezone.utc).isoformat()
        payload = {
            "status": status.value if hasattr(status, "value") else str(status),
            "updated_at": now_str
        }
        if plan is not None:
            payload["plan"] = plan
        if result is not None:
            payload["result"] = result
        if error is not None:
            payload["error"] = error

        url = f"/rest/v1/pc_commands?id=eq.{cmd_id}"
        async with self._client() as client:
            resp = await client.patch(url, json=payload)
            return resp.status_code in (200, 204)

    async def heartbeat(self, online: bool = True, busy: bool = False, version: str = "0.1.0") -> bool:
        """pc_agent_state (id=1) tablosuna canlılık bildirir."""
        now_str = datetime.now(timezone.utc).isoformat()
        payload = {
            "online": online,
            "busy": busy,
            "version": version,
            "last_seen": now_str
        }
        url = "/rest/v1/pc_agent_state?id=eq.1"
        try:
            async with self._client() as client:
                resp = await client.patch(url, json=payload)
                return resp.status_code in (200, 204)
        except Exception as e:
            logger.warning(f"Heartbeat gönderilemedi: {e}")
            return False

    async def create_pairing_session(self, code: str) -> bool:
        """PC eşleştirmesi için pairing_sessions tablosuna geçici PIN kaydeder."""
        payload = {
            "device_type": "pc",
            "device_name": self.hostname,
            "pairing_token": code.upper()
        }
        url = "/rest/v1/pairing_sessions"
        try:
            async with self._client() as client:
                resp = await client.post(url, json=payload)
                return resp.status_code in (200, 201)
        except Exception as e:
            logger.warning(f"Eşleşme oturumu oluşturulamadı: {e}")
            return False

    async def check_pairing_status(self, code: str) -> Optional[str]:
        """Eşleşme PIN'inin telefon tarafından sahiplenilip sahiplenilmediğini kontrol eder."""
        url = f"/rest/v1/pairing_sessions?pairing_token=eq.{code.upper()}&select=claimed_by"
        try:
            async with self._client() as client:
                resp = await client.get(url)
                if resp.status_code == 200:
                    data = resp.json()
                    if data and data[0].get("claimed_by"):
                        return data[0]["claimed_by"]
        except Exception as e:
            logger.warning(f"Eşleşme durumu sorgulanamadı: {e}")
        return None

    async def get_pc_owner(self) -> Optional[str]:
        """pc_agent_state tablosundaki mevcut sahip ID'sini döner."""
        url = "/rest/v1/pc_agent_state?id=eq.1&select=owner_id"
        try:
            async with self._client() as client:
                resp = await client.get(url)
                if resp.status_code == 200:
                    data = resp.json()
                    if data:
                        return data[0].get("owner_id")
        except Exception as e:
            pass
        return None

    async def set_pc_owner(self, owner_id: str) -> bool:
        """pc_agent_state tablosuna kalıcı sahip ID'sini yazar."""
        url = "/rest/v1/pc_agent_state?id=eq.1"
        try:
            async with self._client() as client:
                resp = await client.patch(url, json={"owner_id": owner_id, "pc_name": self.hostname})
                return resp.status_code in (200, 204)
        except Exception as e:
            return False

    async def say(self, text: str) -> bool:
        """
        Kairon robotunun konuşması için robot_state.pending_say alanına yazar.
        Kısıt: En fazla 250 karakter, emoji ve markdown içermemelidir.
        """
        clean_text = text.strip()[:250]
        url = "/rest/v1/robot_state?id=eq.1"
        payload = {"pending_say": clean_text}

        try:
            async with self._client() as client:
                resp = await client.patch(url, json=payload)
                return resp.status_code in (200, 204)
        except Exception as e:
            logger.warning(f"Robot konuşma komutu yazılamadı: {e}")
            return False
