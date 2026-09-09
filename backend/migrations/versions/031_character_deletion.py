"""记录用户删除的角色，阻止内置种子在重启后复活角色。

Revision ID: 031_character_deletion
Revises: 030_user_knowledge_scope
Create Date: 2026-08-10
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "031_character_deletion"
down_revision: Union[str, None] = "030_user_knowledge_scope"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "character_deletion",
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column(
            "deleted_at",
            sa.DateTime(timezone=True),
            nullable=True,
            server_default=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint("character_id"),
    )


def downgrade() -> None:
    op.drop_table("character_deletion")
