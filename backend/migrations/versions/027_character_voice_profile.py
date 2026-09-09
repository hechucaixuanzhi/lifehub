"""每角色独立语音档案

Revision ID: 027_character_voice_profile
Revises: 026_message_context_provenance
Create Date: 2026-08-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "027_character_voice_profile"
down_revision: Union[str, None] = "026_message_context_provenance"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "character_voice_profile",
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("provider", sa.String(), nullable=False, server_default="minimax"),
        sa.Column("source_type", sa.String(), nullable=False, server_default="system"),
        sa.Column("voice_id", sa.String(), nullable=True),
        sa.Column("sample_media_id", sa.String(), nullable=True),
        sa.Column("design_prompt", sa.Text(), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="ready"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("reply_policy", sa.String(), nullable=False, server_default="mirror"),
        sa.Column("speed", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("volume", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("pitch", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("language_boost", sa.String(), nullable=False, server_default="auto"),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("consent_attested_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("character_id"),
    )


def downgrade() -> None:
    op.drop_table("character_voice_profile")
