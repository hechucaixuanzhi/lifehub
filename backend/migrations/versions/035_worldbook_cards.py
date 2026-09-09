"""世界书卡片 + 配角临时成员（035）：worldbook.cards JSON + conversation_member.temporary

Revision ID: 035_worldbook_cards
Revises: 034_message_redpacket_claim
Create Date: 2026-08-11

R6 世界书页面化：
- worldbook.cards：世界卡数组（protagonist|supporting|faction|location|plotline），
  角色卡转成 Character 后回填 character_id；建群时可勾选主角卡一键入群。
- conversation_member.temporary：配角临时加入现有群的标记（前端角标 + 可移除，
  移除不影响角色卡本身）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "035_worldbook_cards"
down_revision: Union[str, None] = "034_message_redpacket_claim"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "worldbook",
        sa.Column(
            "cards", sa.JSON(), nullable=False, server_default=sa.text("'[]'::json")
        ),
    )
    op.add_column(
        "conversation_member",
        sa.Column(
            "temporary",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("conversation_member", "temporary")
    op.drop_column("worldbook", "cards")
