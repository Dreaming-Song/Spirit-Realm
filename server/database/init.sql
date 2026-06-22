-- 灵境 · 数据库初始化脚本 (PostgreSQL)
-- Phase 3: 联机功能

-- 玩家账户表
CREATE TABLE IF NOT EXISTS players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(32) UNIQUE NOT NULL,
    password_hash VARCHAR(256) NOT NULL,
    display_name VARCHAR(32) NOT NULL DEFAULT '',
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    total_play_time INTERVAL DEFAULT '0 seconds'
);

-- 玩家存档表（云端备份）
CREATE TABLE IF NOT EXISTS player_saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    save_data JSONB NOT NULL,
    slot_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(player_id, slot_index)
);

-- 游戏房间历史记录
CREATE TABLE IF NOT EXISTS room_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_name VARCHAR(64) NOT NULL,
    max_players INT DEFAULT 4,
    host_player_id UUID REFERENCES players(id),
    created_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    duration INTERVAL GENERATED ALWAYS AS (ended_at - created_at) STORED
);

-- 灵宠收藏（跨存档保存）
CREATE TABLE IF NOT EXISTS pet_collection (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    pet_type INT NOT NULL,
    pet_name VARCHAR(32) NOT NULL,
    level INT DEFAULT 1,
    loyalty INT DEFAULT 50,
    unlocked_skills TEXT[] DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_player_saves_player ON player_saves(player_id);
CREATE INDEX idx_pet_collection_player ON pet_collection(player_id);
CREATE INDEX idx_room_history_host ON room_history(host_player_id);
