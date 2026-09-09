"""AI 角色反馈（037）——「隐形训练数据收集层」

Revision ID: 037_conversation_feedback
Revises: 036_chat_v2_accept
Create Date: 2026-08-11

V1+V2：气泡右下角小 👍/👎 收集用户对 AI 回复的反馈。
- 核心隔离键 character_id：反馈只优化发出该消息的角色，绝不跨角色污染。
- message_id 唯一 → 每条 AI 消息一条反馈，改主意走 upsert 覆盖（created_at 保留首次）。
- user_message/ai_message 快照 + reasons JSON + preferred_reply：V3（AI 分析 →
  character_learning_profile）的原料，本轮只收数据不消费。
- 无 user_id：单用户设备制，character_id 是唯一归属。
注意：全列不加多余 index（防 034 重复索引教训）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "037_conversation_feedback"
down_revision: Union[str, None] = "036_chat_v2_accept"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "conversation_feedback",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("conversation_id", sa.String(), nullable=False),
        sa.Column("message_id", sa.String(), nullable=False),
        sa.Column("rating", sa.String(), nullable=False),
        sa.Column("user_message", sa.Text(), nullable=True),
        sa.Column("ai_message", sa.Text(), nullable=True),
        sa.Column("reasons", sa.JSON(), nullable=True),
        sa.Column("preferred_reply", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            onupdate=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("message_id"),
    )
    op.create_index(
        "ix_conversation_feedback_character_id",
        "conversation_feedback",
        ["character_id"],
    )
    op.create_index(
        "ix_conversation_feedback_conversation_id",
        "conversation_feedback",
        ["conversation_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_conversation_feedback_conversation_id", table_name="conversation_feedback"
    )
    op.drop_index(
        "ix_conversation_feedback_character_id", table_name="conversation_feedback"
    )
    op.drop_table("conversation_feedback")
