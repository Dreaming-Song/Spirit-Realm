# 数据库设计

## 本地存档（SQLite）

```sql
-- 玩家数据
CREATE TABLE player_data (
    id INTEGER PRIMARY KEY,
    position_x REAL,
    position_y REAL,
    position_z REAL,
    hp INTEGER,
    max_hp INTEGER,
    mp INTEGER,
    max_mp INTEGER,
    current_weapon TEXT,
    current_pet TEXT,
    unlocked_spells TEXT,  -- JSON array
    save_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 背包
CREATE TABLE inventory (
    id INTEGER PRIMARY KEY,
    item_name TEXT,
    item_type TEXT,         -- herb/ore/elixir/weapon
    quantity INTEGER,
    properties TEXT         -- JSON
);

-- 已解锁配方
CREATE TABLE recipes (
    id INTEGER PRIMARY KEY,
    recipe_name TEXT,
    ingredients TEXT,       -- JSON array
    result_item TEXT,
    result_effect TEXT
);

-- 任务进度
CREATE TABLE quest_progress (
    id INTEGER PRIMARY KEY,
    quest_id TEXT,
    quest_name TEXT,
    status TEXT,            -- active/completed/failed
    progress INTEGER
);
```

## 联机数据（PostgreSQL）

```sql
-- 玩家账户
CREATE TABLE players (
    player_id UUID PRIMARY KEY,
    username TEXT UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 联机房间
CREATE TABLE rooms (
    room_id UUID PRIMARY KEY,
    room_name TEXT,
    host_id UUID REFERENCES players(player_id),
    max_players INTEGER DEFAULT 4,
    status TEXT DEFAULT 'waiting',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 联机玩家状态
CREATE TABLE player_online_data (
    player_id UUID REFERENCES players(player_id),
    room_id UUID REFERENCES rooms(room_id),
    position_x REAL,
    position_y REAL,
    position_z REAL,
    hp INTEGER,
    mp INTEGER,
    last_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 操作日志（防作弊）
CREATE TABLE action_log (
    log_id SERIAL PRIMARY KEY,
    player_id UUID REFERENCES players(player_id),
    action_type TEXT,       -- alchemy/magic/combat
    action_data TEXT,       -- JSON
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
