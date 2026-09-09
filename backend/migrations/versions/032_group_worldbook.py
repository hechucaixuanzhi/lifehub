"""群聊 + 世界书（032）：世界书独立表 + 群成员联结 + conversation/message 扩展列

Revision ID: 032_group_worldbook
Revises: 031_character_deletion
Create Date: 2026-08-11

世界观穿越群聊系统：
- worldbook：群聊共享的世界设定（通讯录「标签」），独立实体，群可引用。
- conversation_member：Conversation(type='group') 的成员联结表。
- conversation 加 type/name/worldbook_id/speaker_mode；message 加 sender_character_id。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "032_group_worldbook"
down_revision: Union[str, None] = "031_character_deletion"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- 世界书（通讯录「标签」）----
    op.create_table(
        "worldbook",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("rules", sa.Text(), nullable=True),
        sa.Column("user_identity", sa.Text(), nullable=True),  # 预留
        sa.Column("sort", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    # ---- 群成员联结 ----
    op.create_table(
        "conversation_member",
        sa.Column("conversation_id", sa.String(), nullable=False),
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("world_identity", sa.Text(), nullable=True),  # 预留
        sa.Column("sort", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.PrimaryKeyConstraint("conversation_id", "character_id"),
        sa.ForeignKeyConstraint(
            ["conversation_id"], ["conversation.id"], ondelete="CASCADE"
        ),
    )
    op.create_index(
        "ix_conversation_member_character_id", "conversation_member", ["character_id"]
    )

    # ---- conversation / message 扩展列 ----
    op.add_column(
        "conversation",
        sa.Column("type", sa.String(), nullable=False, server_default="single"),
    )
    op.add_column("conversation", sa.Column("name", sa.String(), nullable=True))
    op.add_column("conversation", sa.Column("worldbook_id", sa.String(), nullable=True))
    op.add_column("conversation", sa.Column("speaker_mode", sa.String(), nullable=True))
    op.add_column("message", sa.Column("sender_character_id", sa.String(), nullable=True))
    op.create_index("ix_message_sender_character_id", "message", ["sender_character_id"])


def downgrade() -> None:
    op.drop_index("ix_message_sender_character_id", table_name="message")
    op.drop_column("message", "sender_character_id")
    op.drop_column("conversation", "speaker_mode")
    op.drop_column("conversation", "worldbook_id")
    op.drop_column("conversation", "name")
    op.drop_column("conversation", "type")
    op.drop_index("ix_conversation_member_character_id", table_name="conversation_member")
    op.drop_table("conversation_member")
    op.drop_table("worldbook")
