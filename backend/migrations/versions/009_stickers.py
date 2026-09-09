"""表情包（009）：sticker 目录表 + message 引用 + media_asset 描述存档

Revision ID: 009_stickers
Revises: 008_wechat_media
Create Date: 2026-08-06

- 新表 sticker（打包进 APK 的静态表情目录）：id=slug=素材文件名，description 即"见过"的
  存档描述（预置中文）→ 内置表情永不调 MiMo
- message 加 sticker_id（kind='sticker' 且为打包表情时引用 sticker.id，渲染本地素材）
- media_asset 加 caption（相册挑图当表情包的 MiMo 描述存档：首次描述后写入，再发/历史复用）
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "009_stickers"
down_revision: Union[str, None] = "008_wechat_media"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- 表情包目录（打包进 APK 的静态表情；后端仅存目录，供 AI 解析/历史标签）----
    op.create_table(
        "sticker",
        sa.Column("id", sa.String(), primary_key=True),  # slug，如 happy
        sa.Column("name", sa.String(), nullable=False),  # 显示名（中文）
        sa.Column("description", sa.Text(), nullable=False),  # 中文描述（AI 上下文/历史标签）
        sa.Column("sort", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    # ---- message：内置表情引用（kind='sticker' 时）----
    op.add_column("message", sa.Column("sticker_id", sa.String(), nullable=True))
    op.create_index("ix_message_sticker_id", "message", ["sticker_id"])

    # ---- media_asset：相册表情包的存档描述（见过复用，不重复调 MiMo）----
    op.add_column("media_asset", sa.Column("caption", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("media_asset", "caption")
    op.drop_index("ix_message_sticker_id", table_name="message")
    op.drop_column("message", "sticker_id")
    op.drop_table("sticker")
