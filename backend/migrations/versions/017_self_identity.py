"""自我识别模块：face_gallery 身份库表

Revision ID: 017_self_identity
Revises: 016_worldview
Create Date: 2026-08-08

设计稿 docs/DESIGN_SELF_IDENTITY.md v1.0：
- 身份库 = character_id → 子身份簇（natural_daily / stage_makeup / selfie / side_profile）→ 多 embedding。
- embedding 存 **BLOB float32 原始字节**（512×4≈2KB/张），不用 TEXT JSON（省 5~10 倍、解析快）。
- 后端纯 stdlib `struct.unpack('=512f', blob)` 解析；不存"平均脸"（明星素颜/舞台/杂志差异大，
  靠多参考图 + 子身份簇覆盖）。
- source_asset_id → media_asset.id 溯源（参考图来自用户相册导入）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "017_self_identity"
down_revision: Union[str, None] = "016_worldview"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "face_gallery",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("character_id", sa.String(), nullable=False),  # companion
        sa.Column("sub_identity", sa.String(), nullable=True),
        # natural_daily | stage_makeup | selfie | side_profile
        sa.Column("embedding", sa.LargeBinary(), nullable=False),  # float32×512 原始字节
        sa.Column("source_asset_id", sa.String(), nullable=True),  # → media_asset.id 溯源
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_face_gallery_character", "face_gallery", ["character_id"])


def downgrade() -> None:
    op.drop_index("ix_face_gallery_character", table_name="face_gallery")
    op.drop_table("face_gallery")
