# 远行商人 · 无服务器部署方案
> 零成本，本地或免费云跑通联机

## 方案一：本地跑 + ngrok 公网穿透（推荐）

最适合你：**零成本，需要联机时开一下就行**

```
你电脑                          朋友电脑
┌────────────┐    ngrok 隧道     ┌────────────┐
│ Godot 游戏  │ ←── 公网URL ──→ │ Godot 游戏  │
│ 后端服务    │                 │            │
│ (localhost) │                 │            │
└────────────┘                 └────────────┘
```

### 步骤
```bash
# 1. 启动后端（你的电脑）
cd server
pip install -r requirements.txt
python main.py
# → 本地 http://localhost:8765

# 2. 开 ngrok 隧道（免费版够用）
ngrok http 8765
# → 得到 https://xxxx.ngrok-free.app

# 3. 把地址告诉朋友
# Godot NetworkManager 里改 server_url 就行
```

## 方案二：Render 免费部署（7x24小时在线）

Render.com 免费套餐：
- Web Service：每月 750 小时（够跑整月）
- PostgreSQL：免费 1GB
- 自动 HTTPS

```bash
# 一键部署按钮（Render 支持直接从 GitHub 拉）
# 1. fork 仓库
# 2. 在 Render 选 Blueprint 部署
# 3. 用 server/render.yaml 自动配置
```

## 方案三：全本地单机 + 联机模拟

不上网也能测试联机效果：
- 在同一台电脑开两个 Godot 实例
- 一个服务器一个客户端
- 或者局域网联机（`ipconfig` 查内网IP）

## 当前能用什么

| 方案 | 成本 | 上线时间 | 适合场景 |
|------|------|---------|---------|
| 本地+ngrok | 免费 | 5分钟 | 临时联机测试/朋友一起玩 |
| Render 部署 | 免费 | 10分钟 | 长期在线服 |
| 纯本地 | 免费 | 马上 | 单人开发测试 |

**我建议先用方案一（本地+ngrok）**，开发测试够了，真想 7x24 在线再走 Render。
