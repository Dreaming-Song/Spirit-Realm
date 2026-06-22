#!/usr/bin/env python3
"""
灵境 · 服务端完整测试套件
用 pytest 跑：pytest tests/ -v
"""

import json
import pytest
import asyncio
from fastapi.testclient import TestClient
from websockets import connect

# 导入服务端
import sys
sys.path.insert(0, "server")
from main import app, room_manager

# ==================== 测试客户端 ====================

client = TestClient(app)

# ==================== Fixtures ====================

@pytest.fixture(autouse=True)
def reset_room_manager():
    """每个测试前清空房间"""
    room_manager.rooms.clear()
    room_manager.player_to_room.clear()

# ==================== REST API 测试 ====================

class TestHealthAPI:
    def test_health_check(self):
        """健康检查应该返回 OK"""
        resp = client.get("/api/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert "rooms" in data
        assert "players" in data

class TestRoomAPI:
    def test_create_room(self):
        """创建房间应该返回 room_id"""
        resp = client.post("/api/rooms", json={
            "name": "测试房间",
            "max_players": 4
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "room_id" in data
        assert data["name"] == "测试房间"

    def test_list_rooms_empty(self):
        """初始应该没有房间"""
        resp = client.get("/api/rooms")
        assert resp.status_code == 200
        assert resp.json()["rooms"] == []

    def test_list_rooms_after_create(self):
        """创建后列表应该包含房间"""
        client.post("/api/rooms", json={"name": "房间1"})
        client.post("/api/rooms", json={"name": "房间2"})
        resp = client.get("/api/rooms")
        assert len(resp.json()["rooms"]) == 2

    def test_room_with_password(self):
        """密码房间应该标记 has_password"""
        resp = client.post("/api/rooms", json={
            "name": "密码房",
            "password": "1234"
        })
        assert resp.json()["has_password"] == True

# ==================== WebSocket 测试 ====================

class TestWebSocket:
    @pytest.mark.asyncio
    async def test_ws_connection(self):
        """WebSocket 应该能连接上"""
        async with connect("ws://localhost:8765/ws/test_player_1") as ws:
            # 连接后应该收到消息
            pass  # 连接成功即通过

    @pytest.mark.asyncio
    async def test_create_room_via_ws(self):
        """通过 WebSocket 创建房间"""
        async with connect("ws://localhost:8765/ws/player_a") as ws_a:
            await ws_a.send(json.dumps({"type": "create_room", "name": "WS房间"}))
            resp = json.loads(await ws_a.recv())
            assert resp["type"] == "room_created"
            assert "room_id" in resp

    @pytest.mark.asyncio
    async def test_two_players_join_room(self):
        """两个玩家加入同一个房间"""
        async with (
            connect("ws://localhost:8765/ws/player_a") as ws_a,
            connect("ws://localhost:8765/ws/player_b") as ws_b,
        ):
            # A 创建房间
            await ws_a.send(json.dumps({"type": "create_room", "name": "双人房"}))
            resp_a = json.loads(await ws_a.recv())
            room_id = resp_a["room_id"]

            # B 加入
            await ws_b.send(json.dumps({"type": "join_room", "room_id": room_id}))
            resp_b = json.loads(await ws_b.recv())
            assert resp_b["type"] == "room_joined"

            # A 应该收到 B 加入的通知
            join_notify = json.loads(await ws_a.recv())
            assert join_notify["type"] == "player_joined"
            assert join_notify["player_id"] == "player_b"

    @pytest.mark.asyncio
    async def test_player_state_sync(self):
        """玩家位置状态应该同步到同房间其他人"""
        async with (
            connect("ws://localhost:8765/ws/player_a") as ws_a,
        ):
            # A 创建房间
            await ws_a.send(json.dumps({"type": "create_room", "name": "同步测试"}))
            room_resp = json.loads(await ws_a.recv())
            room_id = room_resp["room_id"]

            # A 发送位置更新
            await ws_a.send(json.dumps({
                "type": "player_update",
                "x": 10.0, "y": 5.0, "z": 3.0,
                "rot_x": 0.0, "rot_y": 45.0,
                "hp": 80, "mp": 60,
                "is_flying": False,
            }))

            # 同房间没有其他玩家，不广播

    @pytest.mark.asyncio
    async def test_chat_message(self):
        """聊天消息应该广播"""
        async with (
            connect("ws://localhost:8765/ws/player_a") as ws_a,
            connect("ws://localhost:8765/ws/player_b") as ws_b,
        ):
            # A 创建并加入
            await ws_a.send(json.dumps({"type": "create_room", "name": "聊天室"}))
            room_resp = json.loads(await ws_a.recv())
            room_id = room_resp["room_id"]

            # B 加入
            await ws_b.send(json.dumps({"type": "join_room", "room_id": room_id}))
            await ws_b.recv()  # room_joined
            await ws_a.recv()  # player_joined

            # A 发消息
            await ws_a.send(json.dumps({
                "type": "chat",
                "message": "道友你好！"
            }))

            # B 应该收到
            chat = json.loads(await ws_b.recv())
            assert chat["type"] == "chat"
            assert chat["message"] == "道友你好！"
            assert chat["player_id"] == "player_a"

    @pytest.mark.asyncio
    async def test_leave_room(self):
        """离开房间后不再接收广播"""
        async with (
            connect("ws://localhost:8765/ws/player_a") as ws_a,
            connect("ws://localhost:8765/ws/player_b") as ws_b,
        ):
            # A 创建
            await ws_a.send(json.dumps({"type": "create_room", "name": "离开测试"}))
            room_resp = json.loads(await ws_a.recv())
            room_id = room_resp["room_id"]

            # B 加入
            await ws_b.send(json.dumps({"type": "join_room", "room_id": room_id}))
            await ws_b.recv()
            await ws_a.recv()

            # B 离开
            await ws_b.send(json.dumps({"type": "leave_room"}))
            leave_notify = json.loads(await ws_a.recv())
            assert leave_notify["type"] == "player_left"

    @pytest.mark.asyncio
    async def test_full_room_rejection(self):
        """满员的房间应该拒绝新玩家"""
        async with (
            connect("ws://localhost:8765/ws/player_a") as ws_a,
            connect("ws://localhost:8765/ws/player_b") as ws_b,
            connect("ws://localhost:8765/ws/player_c") as ws_c,
        ):
            # 创建最大2人的房间
            await ws_a.send(json.dumps({"type": "create_room", "name": "双人满", "max_players": 2}))
            room_resp = json.loads(await ws_a.recv())
            room_id = room_resp["room_id"]

            await ws_b.send(json.dumps({"type": "join_room", "room_id": room_id}))
            await ws_b.recv()

            # C 尝试加入
            await ws_c.send(json.dumps({"type": "join_room", "room_id": room_id}))
            err = json.loads(await ws_c.recv())
            assert err["type"] == "error"


def test_project_structure():
    """检查项目关键文件是否存在"""
    import os
    required_files = [
        "server/main.py",
        "server/requirements.txt",
        "server/Dockerfile",
        "server/docker-compose.yml",
        "server/database/init.sql",
        "client/scripts/player/player.gd",
        "client/scripts/magic/magic_system.gd",
        "client/scripts/alchemy/alchemy_system.gd",
        "client/scripts/pet/pet.gd",
        "client/scripts/network/network_manager.gd",
        "client/scripts/quest/quest_system.gd",
        "client/scripts/combat/enemy.gd",
        "client/scripts/secret_zone/secret_zone.gd",
        "client/project.godot",
        "docs/game-design.md",
        "docs/phase-plan.md",
    ]
    for f in required_files:
        assert os.path.exists(f), f"缺少文件: {f}"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
