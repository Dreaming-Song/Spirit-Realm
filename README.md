# 灵境 🏮

> 修仙题材开放世界 · 法术炼丹灵宠 · 多人联机探索

## 🎯 核心定位

| 维度 | 说明 |
|------|------|
| 风格 | 国风卡通 · 修仙开放世界 |
| 核心玩法 | 法术战斗、炼丹制药、灵宠培养、秘境探险 |
| 联机规模 | 2-4人轻量联机 |
| 开发周期 | 6个月（5阶段迭代） |
| 目标平台 | PC 端 |

## 🧩 核心特色

| 系统 | 说明 |
|------|------|
| 🪄 **五行法术** | 金木水火土相生相克，物理交互 |
| 🔥 **炼丹系统** | 采集灵草 → 配方合成 → 丹药炼制 |
| 🐉 **灵宠系统** | 收服培养仙兽，随行战斗 |
| ⚔️ **妖兽战斗** | 4种妖兽AI（巡逻/索敌/追击/技能） |
| 🏯 **宗门秘境** | 物理解谜，五行机关，联机组队挑战 |
| 🌐 **联机探索** | 自建 WebSocket 服务端，实时同步 |
| 🎨 **国风渲染** | 自定义 Toon Shader，水墨描边 |

## 🏗️ 技术栈

```
Game Engine:    Godot 4.x (GDScript ~3500行)
Shader:         自定义 Toon Shader + 水墨描边
Networking:     Python FastAPI + WebSocket (自建后端)
Database:       PostgreSQL (联机数据)
CI/CD:          GitHub Actions + pytest
Deployment:     Docker / Render (免费)
Tooling:        Python 脚本
```

## 📅 开发路线图

| 阶段 | 状态 | 产出 |
|------|------|------|
| **Phase 1** 基础搭建 | ✅ | 3D世界、角色控制、交互系统 |
| **Phase 2** 核心玩法 | ✅ | 法术、炼丹、灵宠、存档 |
| **Phase 3** 联机功能 | ✅ | FastAPI+WebSocket 后端、数据库、Docker |
| **Phase 4** 玩法完善 | ✅ | 任务系统、妖兽战斗、秘境解谜 |
| **Phase 5** 测试上线 | 🚧 进行中 | 单元测试、CI、PC端打包 |

## 📁 项目结构

```
├── client/              # Godot 前端
│   ├── scripts/
│   │   ├── player/      # 角色控制器 + 存档
│   │   ├── magic/       # 五行法术系统
│   │   ├── alchemy/     # 炼丹系统
│   │   ├── pet/         # 灵宠系统
│   │   ├── network/     # WebSocket 联机客户端
│   │   ├── quest/       # 任务系统
│   │   ├── combat/      # 妖兽战斗AI
│   │   └── secret_zone/ # 秘境解谜
│   └── shaders/         # 国风Toon Shader
├── server/              # Python 后端
│   ├── main.py          # FastAPI + WebSocket
│   ├── database/        # 建表脚本
│   ├── Dockerfile
│   └── render.yaml      # 免费部署配置
├── tests/               # 测试
├── docs/                # 设计文档
└── .github/workflows/   # CI
```

## 🚀 快速开始

### 启动联机服务端
```bash
cd server
pip install -r requirements.txt
python main.py
# → 监听 ws://0.0.0.0:8765
```

### Docker 部署
```bash
cd server
docker-compose up -d
```

### 运行测试
```bash
pytest tests/test_server.py -v
bash scripts/export_pc.sh 0.1.0
```

### Godot 项目
用 Godot 4.x 打开 `client/project.godot` 即可。
