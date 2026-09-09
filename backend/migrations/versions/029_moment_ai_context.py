"""朋友圈角色自我上下文与时间精度

Revision ID: 029_moment_ai_context
Revises: 028_moments_social
Create Date: 2026-08-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "029_moment_ai_context"
down_revision: Union[str, None] = "028_moments_social"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("moment", sa.Column("ai_context", sa.Text(), nullable=True))
    op.add_column(
        "moment",
        sa.Column(
            "published_precision",
            sa.String(),
            nullable=False,
            server_default="datetime",
        ),
    )


def downgrade() -> None:
    op.drop_column("moment", "published_precision")
    op.drop_column("moment", "ai_context")
