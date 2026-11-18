"""
Supabase Veri Modelleri (Pydantic v2)
"""

from enum import Enum
from typing import Any, Optional
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field

class CommandKind(str, Enum):
    TASK = "task"
    CONFIRM = "confirm"
    CANCEL = "cancel"
    UNDO = "undo"

class CommandStatus(str, Enum):
    PENDING = "pending"
    RECEIVED = "received"
    PLANNING = "planning"
    AWAITING_CONFIRM = "awaiting_confirm"
    RUNNING = "running"
    DONE = "done"
    FAILED = "failed"
    REJECTED = "rejected"
    EXPIRED = "expired"
    CANCELLED = "cancelled"
    UNDONE = "undone"

class Command(BaseModel):
    id: UUID
    created_at: Optional[datetime] = None
    kind: CommandKind = CommandKind.TASK
    utterance: str
    intent: Optional[str] = None
    args: dict[str, Any] = Field(default_factory=dict)
    ref_id: Optional[UUID] = None
    nonce: str
    ts: int
    sig: str
    status: CommandStatus = CommandStatus.PENDING
    plan: Optional[dict[str, Any]] = None
    result: Optional[str] = None
    error: Optional[str] = None
    claimed_by: Optional[str] = None
    claimed_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class AgentState(BaseModel):
    id: int = 1
    online: bool = True
    busy: bool = False
    version: str = "0.1.0"
    last_seen: Optional[datetime] = None
