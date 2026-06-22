# 远行商人 🏮

> 仙侠风格 · 旷野之息式 · 洛克王国式灵宠 · 2-4人联机开放世界

## 🎯 核心定位

| 维度 | 说明 |
|------|------|
| 风格 | 国风卡通/低模仙侠开放世界 |
| 核心玩法 | 物理驱动的仙侠交互（御剑飞行、五行法术、炼丹、灵宠） |
| 联机规模 | 2-4人轻量联机 |
| 地图规模 | 初始 1km²，逐步扩充至 10km² |
| 开发周期 | 6个月（5阶段迭代） |
| 目标平台 | PC 端 |

## 🧩 核心差异化（仙侠 × 旷野之息）

| 旷野之息 | 仙侠改造 |
|---------|---------|
| 滑翔翼 | → **御剑飞行**（物理驱动，气流影响） |
| 元素交互（火/冰/雷） | → **五行法术**（金木水火土） |
| 烹饪系统 | → **炼丹系统**（物理采集 + 配方 DB） |
| 神庙解谜 | → **宗门秘境**（物理解谜，联机组队） |
| 马匹骑行 | → **灵宠随行**（仙鹤、灵狐） |

## 🏗️ 技术栈

```
Game Engine:    Godot 4.x (GDScript)
Modeling:       Blender + Substance Painter + GIMP
Networking:     Photon PUN 2 (frontend) + Python FastAPI/WebSocket (backend)
Database:       SQLite (本地存档) + PostgreSQL (联机数据)
Deployment:     Docker → 阿里云轻量服务器
Tooling:        Python 脚本（批量导出、调试、日志分析）
```

## 📅 开发路线图（6个月）

| 阶段 | 时间 | 状态 | 产出 |
|------|------|------|------|
| **Phase 1** 基础搭建 | 第1个月 | ✅ 代码完成 | 3D仙侠世界（地形、角色、御剑、砍树物理） |
| **Phase 2** 核心玩法 | 第2-3个月 | ✅ 代码完成 | 御剑飞行、五行法术、炼丹、灵宠、存档 |
| **Phase 3** 联机功能 | 第4-5个月 | ✅ 代码完成 | FastAPI+WebSocket 后端、Godot客户端、Docker部署 |
| **Phase 4** 玩法完善 | 第6个月 | ✅ 代码完成 | 任务系统、妖兽战斗、秘境解谜 |
| **Phase 5** 测试上线 | 最后2周 | 🚧 进行中 | 单元测试、CI、PC端打包 |

## 📁 项目结构

```
Merchant-Game/
├── client/              # Godot 前端 (GDScript ~3500行)
│   ├── scripts/
│   │   ├── player/      # 角色控制器 + 存档
│   │   ├── magic/       # 五行法术系统
│   │   ├── alchemy/     # 炼丹系统 + 丹炉节点
│   │   ├── pet/         # 灵宠系统
│   │   ├── network/     # WebSocket 联机客户端
│   │   ├── quest/       # 非线性任务系统
│   │   ├── combat/      # 妖兽战斗AI
│   │   ├── secret_zone/ # 宗门秘境解谜
│   │   └── ui/          # HUD
│   └── project.godot
├── server/              # Python 后端
│   ├── main.py          # FastAPI + WebSocket (320行)
│   ├── database/        # PostgreSQL 建表脚本
│   ├── Dockerfile
│   └── docker-compose.yml
├── tests/               # 测试套件
│   ├── test_server.py   # Python 后端测试 (pytest)
│   └── godot_test_runner.gd
├── docs/                # 设计文档
│   ├── game-design.md
│   ├── art-strategy.md
│   ├── tech-stack.md
│   ├── phase-plan.md
│   └── work-log.md
└── .github/workflows/   # CI 自动测试
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
# 服务端测试
pytest tests/test_server.py -v

# PC 端打包（需要 Godot 导出模板）
bash scripts/export_pc.sh 0.1.0
```

### Godot 项目
用 Godot 4.x 打开 `client/project.godot` 即可。
