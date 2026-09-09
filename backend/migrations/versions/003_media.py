"""media_asset table

Revision ID: 003_media
Revises: 002_sync
Create Date: 2026-08-03

媒体资源元数据：宠物照片 / AI 图片理解复用，业务表只持有 owner 引用，
不直接存路径（见 DATABASE.md §4）。文件本体由 Media Store 落地，本表存元数据。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "003_media"
down_revision: Union[str, None] = "002_sync"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "media_asset",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("owner_type", sa.String(), nullable=False),
        sa.Column("owner_id", sa.String(), nullable=False),
        sa.Column("file_hash", sa.String(), nullable=False),
        sa.Column("storage_path", sa.Text(), nullable=False),
        sa.Column("mime_type", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_media_asset_owner", "media_asset", ["owner_type", "owner_id"])
    op.create_index("ix_media_asset_file_hash", "media_asset", ["file_hash"])


def downgrade() -> None:
    op.drop_index("ix_media_asset_file_hash", table_name="media_asset")
    op.drop_index("ix_media_asset_owner", table_name="media_asset")
    op.drop_table("media_asset")
