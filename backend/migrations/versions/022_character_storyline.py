"""按角色保存故事开场、当前进展与后续方向

Revision ID: 022_character_storyline
Revises: 021_character_user_knowledge
Create Date: 2026-08-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "022_character_storyline"
down_revision: Union[str, None] = "021_character_user_knowledge"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "character_storyline",
        sa.Column("character_id", sa.String(), primary_key=True),
        sa.Column("premise", sa.Text(), nullable=True),
        sa.Column("progress", sa.Text(), nullable=True),
        sa.Column("direction", sa.Text(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")
        ),
    )


def downgrade() -> None:
    op.drop_table("character_storyline")
