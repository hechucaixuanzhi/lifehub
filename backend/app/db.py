"""数据层：引擎 / 会话 / 启动建表。

- 生产：DATABASE_URL 指向 PostgreSQL + pgvector；表结构由 Alembic 管理（migrations/），
  DEV_CREATE_TABLES=false，禁止 create_all 覆盖迁移。
- 本地无 PG：回退 SQLite；DEV_CREATE_TABLES=true 时用 Base.metadata.create_all 快速起库，
  仅用于 Spike / 单测，embedding 以 JSON 文本存储。

模型定义在 app/models.py（供 Alembic 与运行时共享）。
"""
import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool

from . import models

Base = models.Base

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./spike.db")
IS_PG = DATABASE_URL.startswith("postgresql")

# 仅本地/CI 用 create_all 快速建表；生产必须 false，改走 Alembic。
DEV_CREATE_TABLES = os.getenv("DEV_CREATE_TABLES", "true").lower() == "true"

_connect_args = {"check_same_thread": False} if not IS_PG else {}
_engine_kwargs = {"future": True, "connect_args": _connect_args}
if ":memory:" in DATABASE_URL:
    # 内存库 + 线程池（StreamingResponse 走 anyio worker 线程）必须共享单连接，
    # 否则每个线程拿到全新空库。文件型 SQLite / PG 不受影响。
    _engine_kwargs["poolclass"] = StaticPool
engine = create_engine(DATABASE_URL, **_engine_kwargs)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


def init_db() -> None:
    if DEV_CREATE_TABLES:
        # 开发回退：用模型直接建表（含 sync_event / media_asset）。
        # 生产路径下此分支关闭，全部由 Alembic 迁移负责。
        models.Base.metadata.create_all(engine)


# 向后兼容别名：auth.py 等通过 db.Device 访问模型
Device = models.Device
SyncEvent = models.SyncEvent
MediaAsset = models.MediaAsset
Memory = models.Memory
Conversation = models.Conversation
Message = models.Message
Character = models.Character
