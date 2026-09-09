"""用户现实身份、手动关系定义、其他世界用户身份

Revision ID: 020_profile_relationship
Revises: 019_chat_experience
Create Date: 2026-08-09

- user_profile：现实中的用户唯一主资料；
- character_relationship_definition：用户手动设定的关系锚点；
- worldview.user_identity：用户在其他世界的身份，随世界包保存。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "020_profile_relationship"
down_revision: Union[str, None] = "019_chat_experience"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_profile",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("display_name", sa.String(), nullable=False, server_default="我的"),
        sa.Column(
            "lifehub_id", sa.String(), nullable=False, server_default="lifehub_user"
        ),
        sa.Column("avatar_media_id", sa.String(), nullable=True),
        sa.Column("signature", sa.Text(), nullable=True),
        sa.Column(
            "reality_profile",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'{}'::json"),
        ),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")
        ),
    )
    op.create_table(
        "character_relationship_definition",
        sa.Column("character_id", sa.String(), primary_key=True),
        sa.Column("kind", sa.String(), nullable=False, server_default="initial"),
        sa.Column("label", sa.String(), nullable=False, server_default="初识"),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")
        ),
    )
    op.add_column("worldview", sa.Column("user_identity", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("worldview", "user_identity")
    op.drop_table("character_relationship_definition")
    op.drop_table("user_profile")
