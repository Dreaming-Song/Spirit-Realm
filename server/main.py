#!/usr/bin/env python3
"""
灵境 · 游戏服务端
FastAPI + WebSocket 联机后端
"""

import asyncio
import json
import logging
import uuid
from datetime import datetime
from typing import Dict, Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("merchant-server")

# ==================== 数据模型 ====================

class PlayerState(BaseModel):
    """玩家同步状态"""
    player_id: str
    x: float
    y: float
    z: float
    rot_x: float
    rot_y: float
    hp: int
    mp: int
    is_flying: bool
    pet_id: Optional[str] = None

class RoomCreate(BaseModel):
    name: str
    max_players: int = 4
    password: Optional[str] = None

class RoomJoin(BaseModel):
    room_id: str
    password: Optional[str] = None

# ==================== 房间管理器 ====================

class Room:
    """游戏房间"""
    def __init__(self, room_id: str, name: str, max_players: int, password: Optional[str] = None):
        self.room_id = room_id
        self.name = name
        self.max_players = max_players
        self.password = password
        self.players: Dict[str, WebSocket] = {}
        self.player_states: Dict[str, PlayerState] = {}
        self.created_at = datetime.now()

    def is_full(self) -> bool:
        return len(self.players) >= self.max_players

    def add_player(self, player_id: str, ws: WebSocket) -> bool:
        if self.is_full():
            return False
        self.players[player_id] = ws
        self.player_states[player_id] = PlayerState(
            player_id=player_id, x=0, y=2, z=0, rot_x=0, rot_y=0,
            hp=100, mp=100, is_flying=False
        )
        return True

    def remove_player(self, player_id: str) -> None:
        self.players.pop(player_id, None)
        self.player_states.pop(player_id, None)

    def broadcast(self, message: dict, exclude: Optional[str] = None) -> None:
        """广播消息给房间内所有玩家"""
        data = json.dumps(message)
        for pid, ws in self.players.items():
            if pid != exclude:
                asyncio.create_task(ws.send_text(data))

    def to_dict(self) -> dict:
        return {
            "room_id": self.room_id,
            "name": self.name,
            "player_count": len(self.players),
            "max_players": self.max_players,
            "has_password": self.password is not None,
            "created_at": self.created_at.isoformat(),
        }

class RoomManager:
    """全局房间管理器"""
    def __init__(self):
        self.rooms: Dict[str, Room] = {}
        self.player_to_room: Dict[str, str] = {}  # player_id -> room_id

    def create_room(self, name: str, max_players: int = 4, password: Optional[str] = None) -> Room:
        room_id = uuid.uuid4().hex[:8]
        room = Room(room_id, name, max_players, password)
        self.rooms[room_id] = room
        logger.info(f"🏠 房间创建: {room_id} ({name})")
        return room

    def get_room(self, room_id: str) -> Optional[Room]:
        return self.rooms.get(room_id)

    def list_rooms(self) -> list:
        return [r.to_dict() for r in self.rooms.values() if not r.is_full()]

    def join_room(self, room_id: str, player_id: str, ws: WebSocket, password: Optional[str] = None) -> bool:
        room = self.get_room(room_id)
        if not room:
            return False
        if room.password and room.password != password:
            return False
        if not room.add_player(player_id, ws):
            return False
        self.player_to_room[player_id] = room_id

        # 广播新玩家加入
        room.broadcast({
            "type": "player_joined",
            "player_id": player_id,
            "players": list(room.players.keys())
        })
        logger.info(f"👤 {player_id} 加入房间 {room_id}")
        return True

    def leave_room(self, player_id: str) -> None:
        room_id = self.player_to_room.pop(player_id, None)
        if room_id and room_id in self.rooms:
            room = self.rooms[room_id]
            room.remove_player(player_id)
            room.broadcast({
                "type": "player_left",
                "player_id": player_id,
                "players": list(room.players.keys())
            })
            # 空房间自动销毁
            if len(room.players) == 0:
                del self.rooms[room_id]
                logger.info(f"🗑️ 房间销毁: {room_id}")

# ==================== FastAPI 应用 ====================

app = FastAPI(title="灵境 · 联机服务", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

room_manager = RoomManager()

# ----- REST 接口 -----

@app.get("/api/rooms")
async def list_rooms():
    """获取房间列表"""
    return {"rooms": room_manager.list_rooms()}

@app.post("/api/rooms")
async def create_room(data: RoomCreate):
    """创建房间"""
    room = room_manager.create_room(data.name, data.max_players, data.password)
    return {"room_id": room.room_id, "name": room.name}

@app.get("/api/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "rooms": len(room_manager.rooms),
        "players": len(room_manager.player_to_room),
        "uptime": "online"
    }

# ----- WebSocket 接口 -----

@app.websocket("/ws/{player_id}")
async def websocket_endpoint(ws: WebSocket, player_id: str):
    """WebSocket 联机入口"""
    await ws.accept()
    current_room_id: Optional[str] = None

    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = msg.get("type", "")

            if msg_type == "create_room":
                # 创建房间
                room = room_manager.create_room(
                    msg.get("name", f"{player_id}的房间"),
                    msg.get("max_players", 4)
                )
                room_manager.join_room(room.room_id, player_id, ws)
                current_room_id = room.room_id
                await ws.send_text(json.dumps({
                    "type": "room_created",
                    "room_id": room.room_id,
                }))

            elif msg_type == "join_room":
                # 加入房间
                room_id = msg["room_id"]
                pw = msg.get("password")
                if room_manager.join_room(room_id, player_id, ws, pw):
                    current_room_id = room_id
                    await ws.send_text(json.dumps({
                        "type": "room_joined",
                        "room_id": room_id,
                    }))
                else:
                    await ws.send_text(json.dumps({
                        "type": "error",
                        "message": "加入房间失败（房间满/密码错误/不存在）"
                    }))

            elif msg_type == "player_update":
                # 玩家位置同步
                if current_room_id:
                    room = room_manager.get_room(current_room_id)
                    if room and player_id in room.player_states:
                        room.player_states[player_id] = PlayerState(
                            player_id=player_id,
                            x=msg.get("x", 0),
                            y=msg.get("y", 0),
                            z=msg.get("z", 0),
                            rot_x=msg.get("rot_x", 0),
                            rot_y=msg.get("rot_y", 0),
                            hp=msg.get("hp", 100),
                            mp=msg.get("mp", 100),
                            is_flying=msg.get("is_flying", False),
                            pet_id=msg.get("pet_id"),
                        )
                        # 广播给同房间其他玩家
                        room.broadcast({
                            "type": "player_state",
                            "player_id": player_id,
                            "state": room.player_states[player_id].model_dump(),
                        }, exclude=player_id)

            elif msg_type == "chat":
                # 聊天消息
                if current_room_id:
                    room = room_manager.get_room(current_room_id)
                    if room:
                        room.broadcast({
                            "type": "chat",
                            "player_id": player_id,
                            "message": msg.get("message", ""),
                            "timestamp": datetime.now().isoformat(),
                        }, exclude=player_id)

            elif msg_type == "leave_room":
                if current_room_id:
                    room_manager.leave_room(player_id)
                    current_room_id = None

    except WebSocketDisconnect:
        logger.info(f"🔌 {player_id} 断开连接")
    except Exception as e:
        logger.error(f"❌ {player_id} 连接错误: {e}")
    finally:
        if current_room_id:
            room_manager.leave_room(player_id)


if __name__ == "__main__":
    import uvicorn
    logger.info("🚀 灵境 · 联机服务启动")
    uvicorn.run(app, host="0.0.0.0", port=8765)
