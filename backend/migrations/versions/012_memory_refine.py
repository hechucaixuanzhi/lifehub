"""记忆 AI 提炼（012）：memory 版本化 + 留痕/审计表

Revision ID: 012_memory_refine
Revises: 011_entity_snapshot
Create Date: 2026-08-07

借鉴 Mem0（追加式 + 版本化 + 可回滚）：
- memory 加 status（active|superseded|archived）+ superseded_by（被并入谁）+
  refined_at（被提炼时间）；memory_search 只查 active → 提炼后旧记忆自动不再注入。
- memory_revision：每次提炼/回滚写一条留痕（action + 新旧内容），供审计与回滚。
- memory_refine_log：每次提炼跑一轮审计日志，兼作「距上次是否新增记忆」调度跳过依据。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "012_memory_refine"
down_revision: Union[str, None] = "011_entity_snapshot"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # memory 版本化
    op.add_column(
        "memory",
        sa.Column("status", sa.String(), nullable=False, server_default="active"),
    )
    op.add_column("memory", sa.Column("superseded_by", sa.String(), nullable=True))
    op.add_column("memory", sa.Column("refined_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_memory_character_status", "memory", ["character_id", "status"])

    # 提炼留痕（每次变更一行）
    op.create_table(
        "memory_revision",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("memory_id", sa.String(), nullable=False),
        sa.Column("action", sa.String(), nullable=False),
        # action: merged（作为基底被改写）| merged_into（并入他条）| archived | restored
        sa.Column("old_content", sa.Text(), nullable=True),
        sa.Column("new_content", sa.Text(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_memory_revision_memory_id", "memory_revision", ["memory_id"])

    # 提炼审计日志
    op.create_table(
        "memory_refine_log",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("total", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("merged", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("archived", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("unchanged", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("error", sa.Text(), nullable=True),
    )
    op.create_index("ix_memory_refine_log_character", "memory_refine_log", ["character_id"])


def downgrade() -> None:
    op.drop_index("ix_memory_refine_log_character", table_name="memory_refine_log")
    op.drop_table("memory_refine_log")
    op.drop_index("ix_memory_revision_memory_id", table_name="memory_revision")
    op.drop_table("memory_revision")
    op.drop_index("ix_memory_character_status", table_name="memory")
    op.drop_column("memory", "refined_at")
    op.drop_column("memory", "superseded_by")
    op.drop_column("memory", "status")
