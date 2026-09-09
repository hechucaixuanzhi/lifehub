"""AI 角色上下文架构：运行状态 + 条件 Lorebook

Revision ID: 018_character_context
Revises: 017_self_identity
Create Date: 2026-08-08

静态角色定义（Character/Worldview）与动态状态严格分离：
- character_runtime_state：关系、情绪、当前态、Self Model 当前快照；
- character_lore_entry：按关键词/世界/优先级选择注入的角色 Lorebook。

本迁移只建立骨架，不自动生成关系或情绪，不改变既有角色内容。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "018_character_context"
down_revision: Union[str, None] = "017_self_identity"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "character_runtime_state",
        sa.Column("character_id", sa.String(), primary_key=True),
        sa.Column("active_worldview_key", sa.String(), nullable=True, server_default="real"),
        sa.Column("relationship_state", sa.JSON(), nullable=False),
        sa.Column("emotion_state", sa.JSON(), nullable=False),
        sa.Column("current_state", sa.JSON(), nullable=False),
        sa.Column("self_model_state", sa.JSON(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "character_lore_entry",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("trigger_keywords", sa.JSON(), nullable=False),
        sa.Column("worldview_key", sa.String(), nullable=True),
        sa.Column("always_on", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("position", sa.String(), nullable=False, server_default="after_world"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.UniqueConstraint("character_id", "key", name="uq_character_lore_key"),
    )
    op.create_index(
        "ix_character_lore_entry_character",
        "character_lore_entry",
        ["character_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_character_lore_entry_character", table_name="character_lore_entry"
    )
    op.drop_table("character_lore_entry")
    op.drop_table("character_runtime_state")
