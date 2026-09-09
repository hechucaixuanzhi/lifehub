"""人格层结构化：character 表加人格字段（对齐开源角色卡 V2 经验）

Revision ID: 015_persona_layer
Revises: 014_voice_tts
Create Date: 2026-08-08

「AI 回复规范」第一层 = 每个角色的人格层面。参考 SillyTavern 角色卡 V2 与
AI RP 最佳实践：人格拆成结构化字段（性格/口吻/爱好/边界/口头禅/示例对话），
由 prompts.build_persona_system_prompt() 按标准模板确定性组装进 system prompt。
system_prompt / noban_prompt 列保留（物化兜底 + 老路径兼容）。

字段全部 nullable 以兼容 SQLite/PG 两种方言，seed 后 companion/assistant 必填
personality + speech_style（前端不读这些字段，/ai/characters 不透出）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "015_persona_layer"
down_revision: Union[str, None] = "014_voice_tts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("character", sa.Column("personality", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("speech_style", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("interests", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("boundaries", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("catchphrases", sa.Text(), nullable=True))
    op.add_column("character", sa.Column("example_dialogue", sa.Text(), nullable=True))


def downgrade() -> None:
    for col in ("example_dialogue", "catchphrases", "boundaries", "interests",
                "speech_style", "personality"):
        op.drop_column("character", col)
