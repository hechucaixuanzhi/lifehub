"""记忆系统强化（013）：importance 常驻权重 + last_accessed_at 衰减

Revision ID: 013_memory_importance
Revises: 012_memory_refine
Create Date: 2026-08-07

借鉴 Mem0 / Letta：
- importance（0-1）：记忆的持久价值权重。LLM 提取时产出；refine 中 >=0.8 为「常驻」，
  永不 merge-away/archived；<=0.3 且长期未访问为「过时」，refine 保守归档。
- last_accessed_at：检索命中后节流更新（10 分钟窗口），memory_search 排名按
  余弦相似 + importance + 访问新鲜度混合打分。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "013_memory_importance"
down_revision: Union[str, None] = "012_memory_refine"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "memory",
        sa.Column("importance", sa.Float(), nullable=False, server_default=sa.text("0.5")),
    )
    op.add_column(
        "memory",
        sa.Column("last_accessed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_memory_importance", "memory", ["importance"])


def downgrade() -> None:
    op.drop_index("ix_memory_importance", table_name="memory")
    op.drop_column("memory", "last_accessed_at")
    op.drop_column("memory", "importance")
