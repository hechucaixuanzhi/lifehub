"""线性剧情节点与当前位置

Revision ID: 023_storyline_nodes
Revises: 022_character_storyline
Create Date: 2026-08-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "023_storyline_nodes"
down_revision: Union[str, None] = "022_character_storyline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "character_storyline",
        sa.Column(
            "nodes", sa.JSON(), nullable=False, server_default=sa.text("'[]'::json")
        ),
    )
    op.add_column(
        "character_storyline",
        sa.Column("current_node_id", sa.String(), nullable=True),
    )
    op.execute(
        """
        UPDATE character_storyline
        SET nodes = (
                json_build_array(
                    json_build_object(
                        'id', 'start',
                        'title', '初始位置',
                        'content', COALESCE(premise, '')
                    )
                )::jsonb
                || CASE
                    WHEN progress IS NOT NULL AND btrim(progress) <> ''
                    THEN json_build_array(
                        json_build_object(
                            'id', 'legacy_progress',
                            'title', '已有剧情进展',
                            'content', progress
                        )
                    )::jsonb
                    ELSE '[]'::jsonb
                END
                || CASE
                    WHEN direction IS NOT NULL AND btrim(direction) <> ''
                    THEN json_build_array(
                        json_build_object(
                            'id', 'legacy_direction',
                            'title', '后续剧情方向',
                            'content', direction
                        )
                    )::jsonb
                    ELSE '[]'::jsonb
                END
            )::json,
            current_node_id = CASE
                WHEN progress IS NOT NULL AND btrim(progress) <> ''
                THEN 'legacy_progress'
                ELSE 'start'
            END
        WHERE COALESCE(btrim(premise), '') <> ''
           OR COALESCE(btrim(progress), '') <> ''
           OR COALESCE(btrim(direction), '') <> ''
        """
    )


def downgrade() -> None:
    op.drop_column("character_storyline", "current_node_id")
    op.drop_column("character_storyline", "nodes")
