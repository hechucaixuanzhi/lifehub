"""moment table

Revision ID: 004_moment
Revises: 003_media
Create Date: 2026-08-04

私人朋友圈预留（PRD R12 / Phase 2 后半段）：仅表结构，无 UI / 无业务 API。
媒体复用 MediaAsset 多态（owner_type='moment', owner_id=moment.id），不建关联表。
字段对齐 Flutter 端 Moments 表（app/lib/core/database/tables.dart）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "004_moment"
down_revision: Union[str, None] = "003_media"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "moment",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("author_type", sa.String(), nullable=False, server_default="user"),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("visibility", sa.String(), nullable=False, server_default="private"),
        sa.Column("source", sa.String(), nullable=False, server_default="manual"),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_moment_device_id", "moment", ["device_id"])


def downgrade() -> None:
    op.drop_index("ix_moment_device_id", table_name="moment")
    op.drop_table("moment")
