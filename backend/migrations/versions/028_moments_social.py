"""朋友圈多角色、媒体与互动闭环

Revision ID: 028_moments_social
Revises: 027_character_voice_profile
Create Date: 2026-08-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "028_moments_social"
down_revision: Union[str, None] = "027_character_voice_profile"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("moment", sa.Column("character_id", sa.String(), nullable=True))
    op.add_column("moment", sa.Column("source_platform", sa.String(), nullable=True))
    op.add_column("moment", sa.Column("source_url", sa.Text(), nullable=True))
    op.add_column("moment", sa.Column("source_post_id", sa.String(), nullable=True))
    op.add_column("moment", sa.Column("location", sa.String(), nullable=True))
    op.add_column(
        "moment", sa.Column("published_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_index("ix_moment_character_id", "moment", ["character_id"])
    op.create_index("ix_moment_published_at", "moment", ["published_at"])
    op.create_unique_constraint(
        "uq_moment_public_source", "moment", ["source_platform", "source_post_id"]
    )

    op.create_table(
        "moment_media",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("moment_id", sa.String(), nullable=False),
        sa.Column("media_asset_id", sa.String(), nullable=True),
        sa.Column("remote_url", sa.Text(), nullable=True),
        sa.Column("sort", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["moment_id"], ["moment.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_moment_media_moment_id", "moment_media", ["moment_id"])
    op.create_table(
        "moment_like",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("moment_id", sa.String(), nullable=False),
        sa.Column("actor_type", sa.String(), nullable=False),
        sa.Column("actor_id", sa.String(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["moment_id"], ["moment.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "moment_id", "actor_type", "actor_id", name="uq_moment_like_actor"
        ),
    )
    op.create_index("ix_moment_like_moment_id", "moment_like", ["moment_id"])
    op.create_table(
        "moment_comment",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("moment_id", sa.String(), nullable=False),
        sa.Column("actor_type", sa.String(), nullable=False),
        sa.Column("actor_id", sa.String(), nullable=False, server_default=""),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("reply_to_id", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["moment_id"], ["moment.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_moment_comment_moment_id", "moment_comment", ["moment_id"])


def downgrade() -> None:
    op.drop_table("moment_comment")
    op.drop_table("moment_like")
    op.drop_table("moment_media")
    op.drop_constraint("uq_moment_public_source", "moment", type_="unique")
    op.drop_index("ix_moment_published_at", table_name="moment")
    op.drop_index("ix_moment_character_id", table_name="moment")
    for column in (
        "published_at",
        "location",
        "source_post_id",
        "source_url",
        "source_platform",
        "character_id",
    ):
        op.drop_column("moment", column)
