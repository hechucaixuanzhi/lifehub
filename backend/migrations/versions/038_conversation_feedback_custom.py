"""AI 角色反馈扩展（038）—— 点踩原因多选 + 自由填写

Revision ID: 038_conversation_feedback_custom
Revises: 037_conversation_feedback
Create Date: 2026-08-11

点踩不再只选固定原因：新增 custom_feedback 自由文本列，收集「其他」里
藏着的黄金信息（如「她的语气太正式」「想让她主动一点」），
作为 V3 学习层的原料。可空，未填为 NULL。纯加列，不破坏既有行。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "038_conversation_feedback_custom"
down_revision: Union[str, None] = "037_conversation_feedback"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "conversation_feedback",
        sa.Column("custom_feedback", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("conversation_feedback", "custom_feedback")
