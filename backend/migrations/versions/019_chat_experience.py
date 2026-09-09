"""微信聊天体验：引用持久化 + 回复模式

Revision ID: 019_chat_experience
Revises: 018_character_context
Create Date: 2026-08-08

- message 保存引用来源和引用正文，历史组装时提供给 LLM；
- conversation 保存现实聊天/剧情扮演回复模式。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "019_chat_experience"
down_revision: Union[str, None] = "018_character_context"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "conversation",
        sa.Column(
            "reply_mode", sa.String(), nullable=False, server_default="realtime"
        ),
    )
    op.add_column(
        "message", sa.Column("quote_message_id", sa.String(), nullable=True)
    )
    op.add_column("message", sa.Column("quote_role", sa.String(), nullable=True))
    op.add_column("message", sa.Column("quote_content", sa.Text(), nullable=True))
    op.create_index(
        "ix_message_quote_message_id", "message", ["quote_message_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_message_quote_message_id", table_name="message")
    op.drop_column("message", "quote_content")
    op.drop_column("message", "quote_role")
    op.drop_column("message", "quote_message_id")
    op.drop_column("conversation", "reply_mode")
