"""红包/转账（033）：message 加 redpacket_amount 金额列

Revision ID: 033_message_redpacket
Revises: 032_group_worldbook
Create Date: 2026-08-11

转账红包系统（假钱社交信号）：kind='redpacket'|'transfer' 时带金额，
AI 角色仅当收到红包/转账的社交信号感知（无真实支付）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "033_message_redpacket"
down_revision: Union[str, None] = "032_group_worldbook"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "message",
        sa.Column("redpacket_amount", sa.Numeric(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("message", "redpacket_amount")
