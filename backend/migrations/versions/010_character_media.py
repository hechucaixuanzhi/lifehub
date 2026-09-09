"""AI 角色自定义（010）：character 加头像/背景图引用

Revision ID: 010_character_media
Revises: 009_stickers
Create Date: 2026-08-07

- character 加 avatar_media_id / background_media_id（指向 media_asset.id，NULL=默认 glyph/灰底）
- 不加外键约束：防孤儿 id 阻塞；PATCH 时前端/后端做存在性校验
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "010_character_media"
down_revision: Union[str, None] = "009_stickers"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("character", sa.Column("avatar_media_id", sa.String(), nullable=True))
    op.add_column("character", sa.Column("background_media_id", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("character", "background_media_id")
    op.drop_column("character", "avatar_media_id")
