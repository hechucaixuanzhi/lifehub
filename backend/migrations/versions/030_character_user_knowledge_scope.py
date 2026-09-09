"""角色用户认知改为默认拒绝，并将角色专属交互从全局用户资料迁出。

Revision ID: 030_user_knowledge_scope
Revises: 029_moment_ai_context
Create Date: 2026-08-10
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "030_user_knowledge_scope"
down_revision: Union[str, None] = "029_moment_ai_context"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_ROLE_ONLY_FIELDS = ("character_call_name", "meeting_story", "notes")


def upgrade() -> None:
    op.add_column(
        "character_user_knowledge",
        sa.Column(
            "inherit_profile",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    connection = op.get_bind()
    profile_table = sa.table(
        "user_profile",
        sa.column("id", sa.String()),
        sa.column("reality_profile", sa.JSON()),
    )
    knowledge_table = sa.table(
        "character_user_knowledge",
        sa.column("character_id", sa.String()),
        sa.column("inherit_profile", sa.Boolean()),
        sa.column("field_overrides", sa.JSON()),
        sa.column("hidden_fields", sa.JSON()),
        sa.column("version", sa.Integer()),
    )

    profile_row = connection.execute(
        sa.select(profile_table.c.reality_profile).where(profile_table.c.id == "owner")
    ).first()
    reality_profile = dict(profile_row[0] or {}) if profile_row else {}
    moved = {
        key: reality_profile.pop(key)
        for key in _ROLE_ONLY_FIELDS
        if isinstance(reality_profile.get(key), str)
        and reality_profile.get(key).strip()
    }
    if profile_row and moved:
        connection.execute(
            profile_table.update()
            .where(profile_table.c.id == "owner")
            .values(reality_profile=reality_profile)
        )

    companion_row = connection.execute(
        sa.select(
            knowledge_table.c.field_overrides,
            knowledge_table.c.hidden_fields,
            knowledge_table.c.version,
        ).where(knowledge_table.c.character_id == "companion")
    ).first()
    if companion_row:
        overrides = dict(companion_row[0] or {})
        for key, value in moved.items():
            overrides.setdefault(key, value)
        connection.execute(
            knowledge_table.update()
            .where(knowledge_table.c.character_id == "companion")
            .values(
                inherit_profile=True,
                field_overrides=overrides,
                version=int(companion_row[2] or 0) + 1,
            )
        )
    elif moved:
        connection.execute(
            knowledge_table.insert().values(
                character_id="companion",
                inherit_profile=True,
                field_overrides=moved,
                hidden_fields=[],
                version=1,
            )
        )


def downgrade() -> None:
    op.drop_column("character_user_knowledge", "inherit_profile")
