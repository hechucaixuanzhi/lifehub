"""转账接受/婉拒 + 群聊背景/回复限制（036）

Revision ID: 036_chat_v2_accept
Revises: 035_worldbook_cards
Create Date: 2026-08-11

验收批2：
- message.transfer_accepted：AI 对转账「接受(true)/婉拒(false)」，null=待回应。
  提示词让模型在回复最前写 [接受]/[婉拒] 标记，生成后解析落库。
- conversation.background_media_id：群聊聊天背景（指向 media_asset）。
- conversation.reply_chars_realtime / reply_chars_roleplay / reply_count：
  群聊回复「字数/条数」限制，群设置可调、后端持久化。
注意：全列不加 index（防 034 重复索引教训）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "036_chat_v2_accept"
down_revision: Union[str, None] = "035_worldbook_cards"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "message",
        sa.Column("transfer_accepted", sa.Boolean(), nullable=True),
    )
    op.add_column(
        "conversation",
        sa.Column("background_media_id", sa.String(), nullable=True),
    )
    op.add_column(
        "conversation",
        sa.Column(
            "reply_chars_realtime",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("180"),
        ),
    )
    op.add_column(
        "conversation",
        sa.Column(
            "reply_chars_roleplay",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("1000"),
        ),
    )
    op.add_column(
        "conversation",
        sa.Column(
            "reply_count",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("1"),
        ),
    )


def downgrade() -> None:
    op.drop_column("conversation", "reply_count")
    op.drop_column("conversation", "reply_chars_roleplay")
    op.drop_column("conversation", "reply_chars_realtime")
    op.drop_column("conversation", "background_media_id")
    op.drop_column("message", "transfer_accepted")
