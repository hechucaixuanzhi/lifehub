"""红包领取状态（034）：message 加 claimed/claim_time + redpacket_claim 领取表

Revision ID: 034_message_redpacket_claim
Revises: 033_message_redpacket
Create Date: 2026-08-11

AI 收到红包必回并「领取」：redpacket_claimed 标记红包是否已被领取（AI 或用户），
redpacket_claim 表记录每条领取（群红包多人拆，一人一行；character_id=NULL=用户）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "034_message_redpacket_claim"
down_revision: Union[str, None] = "033_message_redpacket"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "message",
        sa.Column(
            "redpacket_claimed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "message",
        sa.Column("redpacket_claim_time", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        "redpacket_claim",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "message_id",
            sa.String(),
            sa.ForeignKey("message.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("character_id", sa.String(), nullable=True, index=True),
        sa.Column(
            "claimed_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("redpacket_claim")
    op.drop_column("message", "redpacket_claim_time")
    op.drop_column("message", "redpacket_claimed")
