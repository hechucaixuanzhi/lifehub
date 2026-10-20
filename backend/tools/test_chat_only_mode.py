"""Dependency-free behavioral checks: python -m unittest discover -s tools -p test_chat_only_mode.py."""
import ast
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

APP = Path(__file__).resolve().parents[1] / "app"


def source(name):
    return ast.parse((APP / name).read_text(encoding="utf-8"))


def execute(nodes, namespace):
    module = ast.Module(body=nodes, type_ignores=[])
    exec(compile(ast.fix_missing_locations(module), "<mode-test>", "exec"), namespace)


def gate(tree):
    return next(node for node in tree.body if isinstance(node, ast.If)
                and ast.unparse(node.test) == "not config.LIFE_TRACKING_ENABLED")


class ChatOnlyModeTests(unittest.TestCase):
    def test_default_and_restore_configuration(self):
        assignment = next(n for n in source("config.py").body
                          if isinstance(n, ast.Assign)
                          and any(isinstance(t, ast.Name) and t.id == "LIFE_TRACKING_ENABLED"
                                  for t in n.targets))
        for value, expected in ((None, False), ("false", False), ("true", True)):
            env = {} if value is None else {"LIFE_TRACKING_ENABLED": value}
            with self.subTest(value=value), patch.dict(os.environ, env, clear=True):
                ns = {"os": os}
                execute([assignment], ns)
                self.assertIs(ns["LIFE_TRACKING_ENABLED"], expected)

    def test_only_life_routes_are_hidden_and_restore_keeps_them(self):
        paths = ["/sync/push", "/sync/pull", "/timeline", "/mi_fitness/status",
                 "/ai/chat", "/ai/groups", "/ai/memory/list", "/worldbooks",
                 "/media", "/moments", "/auth/register", "/health"]
        for enabled in (False, True):
            with self.subTest(enabled=enabled):
                app = SimpleNamespace(router=SimpleNamespace(
                    routes=[SimpleNamespace(path=p) for p in paths]))
                execute([gate(source("main.py"))], {
                    "config": SimpleNamespace(LIFE_TRACKING_ENABLED=enabled), "app": app})
                expected = paths if enabled else paths[4:]
                self.assertEqual([r.path for r in app.router.routes], expected)

    def test_tool_advertisement_retains_memory_and_can_restore_all_tools(self):
        tree = source("ai_gateway.py")
        assignment = next(n for n in tree.body if isinstance(n, ast.Assign)
                          and any(isinstance(t, ast.Name) and t.id == "AI_TOOLS" for t in n.targets))
        original = ast.literal_eval(assignment.value)
        for enabled in (False, True):
            ns = {"config": SimpleNamespace(LIFE_TRACKING_ENABLED=enabled)}
            execute([assignment, gate(tree)], ns)
            names = [t["function"]["name"] for t in ns["AI_TOOLS"]]
            self.assertEqual(names, [t["function"]["name"] for t in original]
                             if enabled else ["search_memories"])

    def test_hidden_tool_cannot_be_invoked_from_old_history(self):
        tree = source("ai_gateway.py")
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef)
                        and n.name == "_execute_tool")
        query = Mock(return_value=[{"steps": 123}])
        memory = Mock(return_value=[{"content": "remembered"}])
        mcp = Mock(return_value={"result": "ok"})
        config = SimpleNamespace(LIFE_TRACKING_ENABLED=False)
        ns = {"config": config, "_query_steps": query,
              "_search_memories": memory, "_execute_mcp_tool": mcp}
        execute([function], ns)
        dispatch = ns["_execute_tool"]
        self.assertIn("error", dispatch("query_steps", {}, "companion"))
        query.assert_not_called()
        self.assertEqual(dispatch("search_memories", {}, "companion"), [{"content": "remembered"}])
        memory.assert_called_once_with({}, "companion")
        self.assertEqual(dispatch("mcp__demo__roll_dice", {}, "companion"), {"result": "ok"})
        config.LIFE_TRACKING_ENABLED = True
        self.assertEqual(dispatch("query_steps", {}, "companion"), [{"steps": 123}])

    def test_startup_keeps_chat_services_and_gates_life_jobs(self):
        function = next(n for n in source("main.py").body
                        if isinstance(n, ast.FunctionDef) and n.name == "_startup")
        function.decorator_list = []
        for enabled in (False, True):
            with self.subTest(enabled=enabled):
                session = Mock()
                session_factory = Mock()
                session_factory.return_value.__enter__ = Mock(return_value=session)
                session_factory.return_value.__exit__ = Mock(return_value=False)
                db = SimpleNamespace(init_db=Mock(), SessionLocal=session_factory)
                fitness = SimpleNamespace(start_scheduler=Mock())
                snapshot = SimpleNamespace(ensure_snapshot=Mock())
                memory = SimpleNamespace(start_scheduler=Mock())
                characters = SimpleNamespace(seed_characters=Mock())
                ns = {"config": SimpleNamespace(LIFE_TRACKING_ENABLED=enabled),
                      "db": db, "mi_fitness_sync": fitness, "snapshot": snapshot,
                      "memory_refine": memory, "character_seeds": characters,
                      "public_moment_seeds": SimpleNamespace(seed_public_moments=Mock()),
                      "sticker_seeds": SimpleNamespace(seed_stickers=Mock())}
                execute([function], ns)
                ns["_startup"]()
                self.assertEqual(fitness.start_scheduler.call_count, int(enabled))
                self.assertEqual(snapshot.ensure_snapshot.call_count, int(enabled))
                characters.seed_characters.assert_called_once()
                memory.start_scheduler.assert_called_once()


if __name__ == "__main__":
    unittest.main()
