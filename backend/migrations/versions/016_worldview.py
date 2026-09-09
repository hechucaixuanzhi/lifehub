"""「AI 回复规范」9 层骨架：外貌/原世界记忆字段 + worldview 表

Revision ID: 016_worldview
Revises: 015_persona_layer
Create Date: 2026-08-08

9 层系统落地（每层先简单占位，内容由用户后续逐层给初版并持续优化）：
- 3 外貌层：character.appearance（Face/Body/Aura 文本）
- 4/5/7 世界观层：新表 worldview（当前世界观书，默认现实世界；后续可加多本）
- 原世界记忆（Origin）开关 + 内容：
  character.origin_world_enabled（bool，默认保留=现实连续模式）
  character.origin_identity / origin_memory / relationship（现实记忆书，先文本字段）
- 1/2 人格层已在 015；8 记忆层已有 memory 表；6 关系层先并入 relationship 字段；
  9 当前状态层每轮动态注入（不建表）。

世界观切换 = 换 worldview 记录，人格卡（Core/Speech/Appearance）不动。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "016_worldview"
down_revision: Union[str, None] = "015_persona_layer"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- 3 外貌层 + 原世界记忆（Origin）----
    op.add_column("character", sa.Column("appearance", sa.Text(), nullable=True))
    op.add_column("character", sa.Column(
        "origin_world_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")))
    op.add_column("character", sa.Column("origin_identity", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("origin_memory", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("relationship", sa.Text(), nullable=True))

    # ---- 世界观书（4/5/7）：每角色可多本，默认现实；切换世界观 = 换 enabled 行 ----
    op.create_table(
        "worldview",
        sa.Column("id", sa.String(), primary_key=True),  # f"{character_id}:{key}"
        sa.Column("character_id", sa.String(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),  # real | xianxia | ...
        sa.Column("name", sa.String(), nullable=False),  # 显示名「现实世界」
        sa.Column("identity", sa.Text(), nullable=True),  # 4 当前世界身份（姓名/年龄/身份/家庭/职业）
        sa.Column("backstory", sa.Text(), nullable=True),  # 5 当前世界经历（童年/转折/成就）
        sa.Column("rules", sa.Text(), nullable=True),  # 世界规则/社会背景
        sa.Column("preferences", sa.Text(), nullable=True),  # 7 偏好与习惯（该世界内）
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("sort", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_worldview_character", "worldview", ["character_id"])


def downgrade() -> None:
    op.drop_index("ix_worldview_character", table_name="worldview")
    op.drop_table("worldview")
    for col in ("relationship", "origin_memory", "origin_identity",
                "origin_world_enabled", "appearance"):
        op.drop_column("character", col)
