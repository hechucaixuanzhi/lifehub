-- 清理 e2e 验证脚本污染的测试会话（2026-08-07，仅删除测试数据，真实会话保留）
BEGIN;

-- 08-07 柠檬水记忆测试（e2e_memory_importance）
-- 08-07 MCP 时间/骰子测试（e2e_mcp_chat）
-- 08-07 读库周报测试（e2e_ai_readlib2）
-- 08-06 读库/步数/时间线/ping 测试
DELETE FROM message
WHERE conversation_id IN (
  '019fd9ed-10e6-7e91-43a0-d434df581aca',
  '019fd9ed-24d7-7287-9dec-2948da9f6467',
  '019fd9ef-551d-7591-63f2-7b6b3798a87d',
  '019fd9ef-5f7d-72b6-be40-431f0d81c7ad',
  '019fd9fa-341c-79aa-015d-d56a210e3788',
  '019fd9fa-41fe-71a2-20aa-8b27371e9fe2',
  '019fd9fa-50f4-71b2-8c8f-3b2a5d0c8d01',
  '019fd9fb-0933-789d-7039-e7c5b3b0acb7',
  '019fd9fb-135b-7992-754b-ed93e16499e2',
  '019fd9fb-c670-70a0-195a-cb2679e7e127',
  '019fd9fb-d0a6-7685-6374-30455c35797f',
  '019fd9fb-e15c-7d9a-7591-78c2abbfd490',
  '019fd9fc-6c0a-74a4-972c-4e5bcaf063eb',
  '019fd9fc-76c2-7da0-4745-9dbdeeaf5df7',
  '019fd9fc-87e7-7f9f-69c5-05a560b1e490',
  '019fd9fe-3642-72ac-9bbb-af2eb81db487',
  '019fd9fe-3eca-7bb8-713f-e8b791b5028a',
  '019fd9fe-5000-74b7-9653-aa30ae64422d',
  '019fda00-79e8-7999-bab9-a898be4342f0',
  '019fda00-81b7-79b6-a77b-fc64ab9fda2d',
  '019fda01-fffa-7cb6-5123-928e6db50bb6',
  '019fda02-0938-7bbc-8c5d-b850f44739b8',
  '019fda02-16ff-7f82-9f3e-614b41627b5b',
  '019fda02-aae5-76ab-2161-ad1446735030',
  '019fda02-dae1-7196-37c4-7af64c54b0ae',
  '019fda03-2093-749d-9526-14e1433cc178',
  '019fd9f3-10f1-75b8-ff07-b2c0a0153231',
  '019fd9f3-8d9d-78b6-ced4-5adf819f4b61',
  '019fd887-65bd-7984-ed67-a350acf16040',
  '019fd887-bcc5-77bb-f2e9-bfa067699370',
  '019fd65c-9035-7b90-e97d-9d72fbde9ab8',
  '019fd661-483b-7d89-f6ce-b9d22841890f',
  '019fd663-04ca-7088-12aa-c65e1bfc33bc',
  '019fd665-2634-76ad-c1d5-f23b03c66112',
  '019fd665-3f91-76a8-0863-4ac2c3584ff4',
  '019fd538-e086-7c8d-a194-6724d7c811e1',
  '019fd5d3-958b-72af-3b04-a07a81d61f42',
  '019fd7dd-28b6-7fbb-ede0-497cd5a1fa79'
);

DELETE FROM conversation
WHERE id IN (
  '019fd9ed-10e6-7e91-43a0-d434df581aca',
  '019fd9ed-24d7-7287-9dec-2948da9f6467',
  '019fd9ef-551d-7591-63f2-7b6b3798a87d',
  '019fd9ef-5f7d-72b6-be40-431f0d81c7ad',
  '019fd9fa-341c-79aa-015d-d56a210e3788',
  '019fd9fa-41fe-71a2-20aa-8b27371e9fe2',
  '019fd9fa-50f4-71b2-8c8f-3b2a5d0c8d01',
  '019fd9fb-0933-789d-7039-e7c5b3b0acb7',
  '019fd9fb-135b-7992-754b-ed93e16499e2',
  '019fd9fb-c670-70a0-195a-cb2679e7e127',
  '019fd9fb-d0a6-7685-6374-30455c35797f',
  '019fd9fb-e15c-7d9a-7591-78c2abbfd490',
  '019fd9fc-6c0a-74a4-972c-4e5bcaf063eb',
  '019fd9fc-76c2-7da0-4745-9dbdeeaf5df7',
  '019fd9fc-87e7-7f9f-69c5-05a560b1e490',
  '019fd9fe-3642-72ac-9bbb-af2eb81db487',
  '019fd9fe-3eca-7bb8-713f-e8b791b5028a',
  '019fd9fe-5000-74b7-9653-aa30ae64422d',
  '019fda00-79e8-7999-bab9-a898be4342f0',
  '019fda00-81b7-79b6-a77b-fc64ab9fda2d',
  '019fda01-fffa-7cb6-5123-928e6db50bb6',
  '019fda02-0938-7bbc-8c5d-b850f44739b8',
  '019fda02-16ff-7f82-9f3e-614b41627b5b',
  '019fda02-aae5-76ab-2161-ad1446735030',
  '019fda02-dae1-7196-37c4-7af64c54b0ae',
  '019fda03-2093-749d-9526-14e1433cc178',
  '019fd9f3-10f1-75b8-ff07-b2c0a0153231',
  '019fd9f3-8d9d-78b6-ced4-5adf819f4b61',
  '019fd887-65bd-7984-ed67-a350acf16040',
  '019fd887-bcc5-77bb-f2e9-bfa067699370',
  '019fd65c-9035-7b90-e97d-9d72fbde9ab8',
  '019fd661-483b-7d89-f6ce-b9d22841890f',
  '019fd663-04ca-7088-12aa-c65e1bfc33bc',
  '019fd665-2634-76ad-c1d5-f23b03c66112',
  '019fd665-3f91-76a8-0863-4ac2c3584ff4',
  '019fd538-e086-7c8d-a194-6724d7c811e1',
  '019fd5d3-958b-72af-3b04-a07a81d61f42',
  '019fd7dd-28b6-7fbb-ede0-497cd5a1fa79'
);

COMMIT;
