"""角色可见的用户知识视图

Revision ID: 021_character_user_knowledge
Revises: 020_profile_relationship
Create Date: 2026-08-09

用户完整正史保存在 user_profile；每个角色通过覆盖/隐藏字段读取受限视图，
避免角色天然知道用户的全部隐私与背景细节。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "021_character_user_knowledge"
down_revision: Union[str, None] = "020_profile_relationship"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "character_user_knowledge",
        sa.Column("character_id", sa.String(), primary_key=True),
        sa.Column(
            "field_overrides",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'{}'::json"),
        ),
        sa.Column(
            "hidden_fields",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'::json"),
        ),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")
        ),
    )


def downgrade() -> None:
    op.drop_table("character_user_knowledge")
