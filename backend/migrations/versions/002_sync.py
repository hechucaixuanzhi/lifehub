"""sync_event log

Revision ID: 002_sync
Revises: 001_init
Create Date: 2026-08-03

轻量变更日志（非完整事件溯源）：每个本地写操作追加一行，
后端按序 apply 做最终一致 reconcile，并向 AI 暴露变化历史。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "002_sync"
down_revision: Union[str, None] = "001_init"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sync_event",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("entity_type", sa.String(), nullable=False),
        sa.Column("entity_id", sa.String(), nullable=False),
        sa.Column("operation", sa.String(), nullable=False),  # create|update|delete
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("synced_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_sync_event_device_id", "sync_event", ["device_id"])
    op.create_index("ix_sync_event_entity", "sync_event", ["entity_type", "entity_id"])
    op.create_index("ix_sync_event_created_at", "sync_event", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_sync_event_created_at", table_name="sync_event")
    op.drop_index("ix_sync_event_entity", table_name="sync_event")
    op.drop_index("ix_sync_event_device_id", table_name="sync_event")
    op.drop_table("sync_event")
