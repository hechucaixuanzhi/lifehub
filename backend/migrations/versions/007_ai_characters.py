"""AI 角色分层：character 表 + memory/conversation 加 character_id

Revision ID: 007_ai_characters
Revises: 006_mi_fitness
Create Date: 2026-08-06

人格层（character 表）：角色 = 数据，多角色复用。系统提示词以 DB 为准，
启动时由 character_seeds.seed_characters() 幂等 upsert（本迁移不塞 seed 数据）。

记忆层 / 会话层：memory、conversation 各加 character_id（每角色独立记忆/会话）。
存量行 backfill：memory 历史记忆只可能来自 companion → 'companion'；
conversation 自 persona 列（assistant/companion 同语义）拷贝。

PG 下为 memory.embedding 建 HNSW 向量索引（需 vector 扩展，非 PG 方言守卫跳过）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "007_ai_characters"
down_revision: Union[str, None] = "006_mi_fitness"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- 人格层：character 表 ----
    op.create_table(
        "character",
        sa.Column("id", sa.String(), primary_key=True),  # slug: assistant | companion
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("tagline", sa.String(), nullable=True),
        sa.Column("avatar_text", sa.String(), nullable=False),
        sa.Column("avatar_color", sa.String(), nullable=False),  # #RRGGBB
        sa.Column("welcome_message", sa.String(), nullable=True),
        sa.Column("system_prompt", sa.Text(), nullable=False),
        sa.Column("noban_prompt", sa.Text(), nullable=True),  # NULL=不支持无违禁
        sa.Column("memory_enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("sort", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    # ---- 记忆层：memory + character_id ----
    op.add_column("memory", sa.Column("character_id", sa.String(), nullable=True))
    # 历史记忆只可能由 companion（AI 女友）自动写入 → backfill
    op.execute("UPDATE memory SET character_id = 'companion' WHERE character_id IS NULL")
    op.create_index("ix_memory_character_id", "memory", ["character_id"])
    op.create_index("ix_memory_created_at", "memory", ["created_at"])

    # ---- 会话层：conversation + character_id（backfill 自 persona）----
    op.add_column("conversation", sa.Column("character_id", sa.String(), nullable=True))
    op.execute(
        "UPDATE conversation SET character_id = persona "
        "WHERE character_id IS NULL AND persona IS NOT NULL"
    )
    op.create_index("ix_conversation_character_id", "conversation", ["character_id"])

    # ---- PG：HNSW 向量索引（memory.embedding）----
    if op.get_bind().dialect.name == "postgresql":
        op.execute("CREATE EXTENSION IF NOT EXISTS vector")
        op.execute(
            "CREATE INDEX IF NOT EXISTS memory_embedding_idx "
            "ON memory USING hnsw (embedding vector_cosine_ops)"
        )


def downgrade() -> None:
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP INDEX IF EXISTS memory_embedding_idx")
    op.drop_index("ix_conversation_character_id", table_name="conversation")
    op.drop_column("conversation", "character_id")
    op.drop_index("ix_memory_created_at", table_name="memory")
    op.drop_index("ix_memory_character_id", table_name="memory")
    op.drop_column("memory", "character_id")
    op.drop_table("character")
