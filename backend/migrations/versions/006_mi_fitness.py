"""mi_fitness sync tables: 小米运动健康自动同步数据

Revision ID: 006_mi_fitness
Revises: 005_sync_idempotency
Create Date: 2026-08-06

小米运动健康（Mi Fitness）云读取落库：每日活动 / 运动记录 / 心率采样 /
睡眠 / 身体成分 / 血氧 / 压力 / 异常心跳。独立于用户手动录入（device 维度），
App 经签名 endpoint 直接查询。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "006_mi_fitness"
down_revision: Union[str, None] = "005_sync_idempotency"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mi_activity_daily",
        sa.Column("date", sa.String(), primary_key=True),
        sa.Column("steps", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("distance_m", sa.Float(), nullable=False, server_default="0"),
        sa.Column("active_kcal", sa.Float(), nullable=False, server_default="0"),
        sa.Column("timezone", sa.String(), nullable=False, server_default="Asia/Shanghai"),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_table(
        "mi_workout",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("native_id", sa.String(), nullable=False),
        sa.Column("activity_type", sa.String(), nullable=False),
        sa.Column("sport_category", sa.String(), nullable=True),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_min", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("distance_m", sa.Float(), nullable=True),
        sa.Column("calories_kcal", sa.Float(), nullable=True),
        sa.Column("avg_hr_bpm", sa.Integer(), nullable=True),
        sa.Column("max_hr_bpm", sa.Integer(), nullable=True),
        sa.Column("avg_pace_s_per_km", sa.Float(), nullable=True),
        sa.Column("max_pace_s_per_km", sa.Float(), nullable=True),
        sa.Column("total_steps", sa.Integer(), nullable=True),
        sa.Column("raw", sa.JSON(), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_unique_constraint("uq_mi_workout_native_id", "mi_workout", ["native_id"])
    op.create_index("ix_mi_workout_start_at", "mi_workout", ["start_at"])
    op.create_index("ix_mi_workout_activity_type", "mi_workout", ["activity_type"])

    op.create_table(
        "mi_heart_rate",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("bpm", sa.Integer(), nullable=False),
        sa.Column("sample_type", sa.String(), nullable=False, server_default="passive"),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_mi_heart_rate_timestamp", "mi_heart_rate", ["timestamp"])
    op.create_unique_constraint(
        "uq_mi_hr_ts_type", "mi_heart_rate", ["timestamp", "sample_type"]
    )

    op.create_table(
        "mi_sleep",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("sleep_id", sa.String(), nullable=False),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_min", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("awake_min", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("asleep_min", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("score", sa.Integer(), nullable=True),
        sa.Column("is_nap", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("stages", sa.JSON(), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_unique_constraint("uq_mi_sleep_id", "mi_sleep", ["sleep_id"])

    op.create_table(
        "mi_body_measurement",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("bmi", sa.Float(), nullable=True),
        sa.Column("body_fat_pct", sa.Float(), nullable=True),
        sa.Column("muscle_kg", sa.Float(), nullable=True),
        sa.Column("water_pct", sa.Float(), nullable=True),
        sa.Column("bone_kg", sa.Float(), nullable=True),
        sa.Column("visceral_fat_score", sa.Integer(), nullable=True),
        sa.Column("basal_meta_kcal", sa.Integer(), nullable=True),
        sa.Column("body_age", sa.Integer(), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_mi_body_measurement_timestamp", "mi_body_measurement", ["timestamp"])

    op.create_table(
        "mi_spo2",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("spo2_pct", sa.Integer(), nullable=False),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_mi_spo2_timestamp", "mi_spo2", ["timestamp"])

    op.create_table(
        "mi_stress",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("level", sa.String(), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_mi_stress_timestamp", "mi_stress", ["timestamp"])

    op.create_table(
        "mi_abnormal_heartbeat",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_sec", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("synced_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )


def downgrade() -> None:
    op.drop_table("mi_abnormal_heartbeat")
    op.drop_table("mi_stress")
    op.drop_table("mi_spo2")
    op.drop_table("mi_body_measurement")
    op.drop_table("mi_sleep")
    op.drop_table("mi_heart_rate")
    op.drop_table("mi_workout")
    op.drop_table("mi_activity_daily")
