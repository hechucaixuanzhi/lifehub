"""当前态快照（011）：通用 entity_snapshot 镜像表

Revision ID: 011_entity_snapshot
Revises: 010_character_media
Create Date: 2026-08-07

- entity_snapshot：各业务「当前态」镜像（定义类实体：study_resource / exercise_type /
  pet / inbox_item / life_habit），由 /sync/push 增量应用 + 启动全量重放维护。
- 复合主键 (scope, entity_type, entity_id)；payload 为 JSON（对齐 SyncEvent.payload 语义）。
- 通用 JSON 快照 = 按构造对齐真实 Drift 列（payload 即该类型最新完整定义）：
  新增实体类型只需在 snapshot.DEFINITION_TYPES 加分支，不用再迁移。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "011_entity_snapshot"
down_revision: Union[str, None] = "010_character_media"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "entity_snapshot",
        sa.Column("scope", sa.String(), nullable=False, server_default="user"),
        sa.Column("entity_type", sa.String(), nullable=False),
        sa.Column("entity_id", sa.String(), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.PrimaryKeyConstraint("scope", "entity_type", "entity_id"),
    )
    op.create_index(
        "ix_entity_snapshot_type_updated",
        "entity_snapshot",
        ["entity_type", "updated_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_entity_snapshot_type_updated", table_name="entity_snapshot")
    op.drop_table("entity_snapshot")
