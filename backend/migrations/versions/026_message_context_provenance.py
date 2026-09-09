"""聊天消息来源与 AI 上下文排除标记

Revision ID: 026_message_context_provenance
Revises: 025_memory_source_mode
Create Date: 2026-08-09

无违禁消息仍可显示在聊天界面；用户选择剔除相关记忆后，将它们排除出后续模型上下文。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "026_message_context_provenance"
down_revision: Union[str, None] = "025_memory_source_mode"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "message",
        sa.Column(
            "source_mode",
            sa.String(),
            nullable=False,
            server_default="standard",
        ),
    )
    op.add_column(
        "message",
        sa.Column(
            "context_excluded",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.create_index("ix_message_source_mode", "message", ["source_mode"])
    op.create_index(
        "ix_message_context_excluded", "message", ["context_excluded"]
    )


def downgrade() -> None:
    op.drop_index("ix_message_context_excluded", table_name="message")
    op.drop_index("ix_message_source_mode", table_name="message")
    op.drop_column("message", "context_excluded")
    op.drop_column("message", "source_mode")
