"""sync_event idempotency: client_event_id unique per device

Revision ID: 005_sync_idempotency
Revises: 004_moment
Create Date: 2026-08-06

同步幂等去重：客户端 push 附本地事件 id（client_event_id），
服务端按 (device_id, client_event_id) 唯一去重，网络抖动重推不产生重复行。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "005_sync_idempotency"
down_revision: Union[str, None] = "004_moment"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "sync_event",
        sa.Column("client_event_id", sa.String(), nullable=True),
    )
    op.create_index(
        "ix_sync_event_client_event_id",
        "sync_event",
        ["client_event_id"],
    )
    # 幂等唯一键（PG 唯一索引允许多个 NULL，存量行不受影响）
    op.create_unique_constraint(
        "uq_sync_device_client_event",
        "sync_event",
        ["device_id", "client_event_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_sync_device_client_event", "sync_event", type_="unique")
    op.drop_index("ix_sync_event_client_event_id", table_name="sync_event")
    op.drop_column("sync_event", "client_event_id")
