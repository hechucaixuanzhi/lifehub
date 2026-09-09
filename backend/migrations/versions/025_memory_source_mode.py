"""长期记忆来源模式

Revision ID: 025_memory_source_mode
Revises: 024_character_public_history
Create Date: 2026-08-09

无违禁会话自动形成的记忆标记为 noban。关闭模式时，用户可以只剔除这批记忆；
历史记忆回填 standard，默认保留。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "025_memory_source_mode"
down_revision: Union[str, None] = "024_character_public_history"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "memory",
        sa.Column(
            "source_mode",
            sa.String(),
            nullable=False,
            server_default="standard",
        ),
    )
    op.create_index("ix_memory_source_mode", "memory", ["source_mode"])


def downgrade() -> None:
    op.drop_index("ix_memory_source_mode", table_name="memory")
    op.drop_column("memory", "source_mode")
