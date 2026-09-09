"""微信富媒体：message 支持图片/文件，media_asset 上传生命周期，character 文件传输助手

Revision ID: 008_wechat_media
Revises: 007_ai_characters
Create Date: 2026-08-06

- message 加 kind(text|image|file) + media_asset_id + file_name + file_size（图片/文件即消息，
  走现有 /ai/chat + /ai/history 通道，不新增消息同步世界）
- media_asset 加 status(pending→ready)/size/file_name/device_id；owner_id、file_hash 改可空
  （聊天媒体先建元数据、后 PUT 字节，owner 与哈希当时未知）
- character 加 is_file_transfer（文件传输助手=特殊角色：纯存储、不调 AI）
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "008_wechat_media"
down_revision: Union[str, None] = "007_ai_characters"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- message：富媒体字段 ----
    op.add_column("message", sa.Column("kind", sa.String(), nullable=False, server_default="text"))
    op.add_column("message", sa.Column("media_asset_id", sa.String(), nullable=True))
    op.add_column("message", sa.Column("file_name", sa.Text(), nullable=True))
    op.add_column("message", sa.Column("file_size", sa.BigInteger(), nullable=True))
    op.create_index("ix_message_media_asset_id", "message", ["media_asset_id"])

    # ---- media_asset：上传生命周期 ----
    op.add_column("media_asset", sa.Column("status", sa.String(), nullable=False, server_default="pending"))
    op.add_column("media_asset", sa.Column("size", sa.BigInteger(), nullable=True))
    op.add_column("media_asset", sa.Column("file_name", sa.Text(), nullable=True))
    op.add_column("media_asset", sa.Column("device_id", sa.String(), nullable=True))
    op.create_index("ix_media_asset_device_id", "media_asset", ["device_id"])
    # 聊天媒体上传时 owner（message）未建、哈希未算 → 放宽非空
    op.alter_column("media_asset", "owner_id", existing_type=sa.String(), nullable=True)
    op.alter_column("media_asset", "file_hash", existing_type=sa.String(), nullable=True)

    # ---- character：文件传输助手标记 ----
    op.add_column(
        "character",
        sa.Column("is_file_transfer", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )


def downgrade() -> None:
    op.drop_column("character", "is_file_transfer")
    op.drop_index("ix_media_asset_device_id", table_name="media_asset")
    op.drop_column("media_asset", "device_id")
    op.drop_column("media_asset", "file_name")
    op.drop_column("media_asset", "size")
    op.drop_column("media_asset", "status")
    op.alter_column("media_asset", "owner_id", existing_type=sa.String(), nullable=False)
    op.alter_column("media_asset", "file_hash", existing_type=sa.String(), nullable=False)
    op.drop_index("ix_message_media_asset_id", table_name="message")
    op.drop_column("message", "file_size")
    op.drop_column("message", "file_name")
    op.drop_column("message", "media_asset_id")
    op.drop_column("message", "kind")
