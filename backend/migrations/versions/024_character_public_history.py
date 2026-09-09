"""角色公开正史时间线

Revision ID: 024_character_public_history
Revises: 023_storyline_nodes
Create Date: 2026-08-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "024_character_public_history"
down_revision: Union[str, None] = "023_storyline_nodes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "character_public_event",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("event_date", sa.String(), nullable=False),
        sa.Column("end_date", sa.String(), nullable=True),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=False, server_default=sa.text("'[]'::json")),
        sa.Column(
            "source_urls",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'::json"),
        ),
        sa.Column(
            "source_level",
            sa.String(),
            nullable=False,
            server_default="official",
        ),
        sa.Column("importance", sa.Integer(), nullable=False, server_default="50"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint(
            "character_id", "key", name="uq_character_public_event_key"
        ),
    )
    op.create_index(
        "ix_character_public_event_character_date",
        "character_public_event",
        ["character_id", "event_date"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_character_public_event_character_date",
        table_name="character_public_event",
    )
    op.drop_table("character_public_event")
