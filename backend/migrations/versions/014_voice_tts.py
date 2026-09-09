"""AI 语音消息（014）：Message.audio_duration + AppSetting 表

Revision ID: 014_voice_tts
Revises: 013_memory_importance
Create Date: 2026-08-08

- message 加 audio_duration（Integer, nullable）：kind='audio' 时秒数（气泡宽度/时长显示）。
- 新表 app_setting（key, value, updated_at）：存当前克隆音色 voice_id（MiniMax TTS）。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "014_voice_tts"
down_revision: Union[str, None] = "013_memory_importance"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "message",
        sa.Column("audio_duration", sa.Integer(), nullable=True),
    )
    op.create_table(
        "app_setting",
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("value", sa.Text(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("key"),
    )


def downgrade() -> None:
    op.drop_table("app_setting")
    op.drop_column("message", "audio_duration")
