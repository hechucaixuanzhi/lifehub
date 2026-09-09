-- ============================================================
-- LifeHub Backend — 生产 DDL（PostgreSQL + pgvector）
-- Spike 0.1 只建 4 张表；embedding 用 BGE-M3（1024 维）。
-- 与 Alembic 迁移配套；本文件为可读参照，迁移走编号脚本。
-- ============================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- 设备（Device Key Pair 验签）
CREATE TABLE IF NOT EXISTS device (
    device_id  TEXT PRIMARY KEY,
    pubkey     TEXT NOT NULL,            -- Ed25519 公钥（base64 原始 32 字节）
    name       TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 对话会话
CREATE TABLE IF NOT EXISTS conversation (
    id        TEXT PRIMARY KEY,
    persona   TEXT DEFAULT 'assistant',  -- assistant | companion
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 单条消息
CREATE TABLE IF NOT EXISTS message (
    id              TEXT PRIMARY KEY,
    conversation_id TEXT REFERENCES conversation(id),
    role            TEXT,                -- user | assistant
    content         TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- 长期记忆（Memory Service，RAG）
CREATE TABLE IF NOT EXISTS memory (
    id        TEXT PRIMARY KEY,
    type      TEXT,                      -- event | fact | preference
    content   TEXT,
    embedding vector(1024),              -- BGE-M3，1024 维
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 向量余弦检索索引（ivfflat；生产按数据量调 lists）
CREATE INDEX IF NOT EXISTS memory_embedding_idx
    ON memory USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================================
-- Phase 0.5 新增：sync_event（轻量变更日志）+ media_asset（媒体元数据）
-- 与 migrations/ 001~003 对应；本文件为可读参照。
-- ============================================================

-- 同步事件日志（非完整事件溯源）：每个本地写操作追加一行
CREATE TABLE IF NOT EXISTS sync_event (
    id          TEXT PRIMARY KEY,           -- UUIDv7
    device_id   TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   TEXT NOT NULL,
    operation   TEXT NOT NULL,              -- create | update | delete
    payload     JSONB,
    version     INT  DEFAULT 1,             -- 同一实体每变更 +1
    created_at  TIMESTAMPTZ DEFAULT now(),
    synced_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS ix_sync_event_device_id   ON sync_event (device_id);
CREATE INDEX IF NOT EXISTS ix_sync_event_entity      ON sync_event (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS ix_sync_event_created_at  ON sync_event (created_at);

-- 媒体资源元数据（宠物照片 / AI 图片理解复用）
CREATE TABLE IF NOT EXISTS media_asset (
    id           TEXT PRIMARY KEY,
    owner_type   TEXT NOT NULL,             -- pet_log | ai_vision | ...
    owner_id     TEXT NOT NULL,
    file_hash    TEXT NOT NULL,             -- 去重 / 完整性校验
    storage_path TEXT NOT NULL,             -- 对象存储 key 或本地相对路径
    mime_type    TEXT,
    created_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_media_asset_owner      ON media_asset (owner_type, owner_id);
CREATE INDEX IF NOT EXISTS ix_media_asset_file_hash  ON media_asset (file_hash);
