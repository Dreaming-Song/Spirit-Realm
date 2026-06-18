# 技术栈说明

## 游戏引擎：Godot 4.x
- **语言：** GDScript（语法接近 Python）
- **关键节点：** Node3D, CharacterBody3D, Terrain3D, RigidBody3D
- **插件：**
  - Open World 插件（地形构建）
  - Photon PUN 2（联机）
  - 内置 Toon Shader（卡通渲染）

## 建模/美术：Blender + Substance Painter + GIMP
- **建模：** Blender 低模，国风风格
- **贴图：** Substance Painter
- **UI：** GIMP
- **导出格式：** glb（Godot 原生支持）

## 后端：Python
- **框架：** FastAPI（REST API）+ WebSocket（实时通信）
- **数据库：** PostgreSQL（联机数据）+ SQLite（本地存档）
- **部署：** Docker → 阿里云轻量服务器

## 工具链：Python 脚本
- 批量导出模型
- 参数调试
- 日志分析
- 性能监控
