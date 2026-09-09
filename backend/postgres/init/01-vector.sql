-- 启用 pgvector 扩展（首次建库时由 Postgres 入口脚本执行一次）。
-- 迁移 001_init 中的 embedding 列使用 vector(1024) 类型，依赖本扩展；
-- 不在迁移内 CREATE EXTENSION，保持迁移与 models.py 单一事实来源干净。
CREATE EXTENSION IF NOT EXISTS vector;
