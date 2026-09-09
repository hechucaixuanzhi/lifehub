"""WS4 演示 MCP 服务器（stdio，纯标准库）—— 验证客户端互通与聊天集成。

运行：python app/mcp_demo_server.py（被 lifehub-backend 以子进程拉起）
约定：stdout 只输出协议（每行一个 JSON-RPC 响应）；一切日志走 stderr。
工具：get_current_time / roll_dice / calculator(ast 安全求值) / get_weather(open-meteo)。
"""
import ast
import json
import random
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone


def _now() -> str:
    bj = datetime.now(timezone.utc) + timedelta(hours=8)
    return bj.strftime("%Y-%m-%d %H:%M:%S（北京时间）")


def _roll(dice: str = "1d6") -> dict:
    n, _, sides = dice.partition("d")
    try:
        n = int(n) or 1
        sides = int(sides)
    except ValueError:
        return {"error": "格式应为 NdM，如 2d6"}
    n = max(1, min(n, 100))
    sides = max(1, min(sides, 1000))
    rolls = [random.randint(1, sides) for _ in range(n)]
    return {"dice": f"{n}d{sides}", "rolls": rolls, "total": sum(rolls)}


def _calc(expression: str = "") -> dict:
    if not isinstance(expression, str) or not expression.strip():
        return {"error": "缺表达式"}
    tree = ast.parse(expression, mode="eval")
    allowed = (ast.Expression, ast.BinOp, ast.UnaryOp, ast.Constant,
               ast.Add, ast.Sub, ast.Mult, ast.Div, ast.FloorDiv, ast.Mod, ast.Pow,
               ast.USub, ast.UAdd)
    for node in ast.walk(tree):
        if not isinstance(node, allowed):
            return {"error": f"不允许的表达式节点: {type(node).__name__}"}
    try:
        result = eval(compile(tree, "<calc>", "eval"), {"__builtins__": {}}, {})
    except Exception as exc:
        return {"error": str(exc)}
    return {"expression": expression, "result": result}


def _weather(city: str = "", units: str = "celsius") -> dict:
    if not city:
        return {"error": "缺城市名"}
    try:
        geoc = json.load(urllib.request.urlopen(
            f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(city)}"
            f"&count=1&language=zh", timeout=8))
        hits = geoc.get("results") or []
        if not hits:
            return {"error": f"找不到城市: {city}"}
        lat, lon = hits[0]["latitude"], hits[0]["longitude"]
        t = json.load(urllib.request.urlopen(
            f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
            f"&current_weather=true&temperature_unit={units}&forecast_days=1", timeout=8))
        cw = t.get("current_weather", {})
        return {"city": hits[0]["name"], "country": hits[0].get("country"),
                "temperature": cw.get("temperature"), "windspeed": cw.get("windspeed"),
                "weathercode": cw.get("weathercode"), "time": cw.get("time")}
    except Exception as exc:
        return {"error": f"查询失败: {exc}"}


TOOLS = [
    {"name": "get_current_time",
     "description": "获取当前北京时间（日期+时刻）。",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "roll_dice",
     "description": "掷骰子，返回点数与总和。格式如 2d6 表示 2 颗 6 面骰。",
     "inputSchema": {"type": "object",
                     "properties": {"dice": {"type": "string", "description": "NdM 格式，默认 1d6"}}}},
    {"name": "calculator",
     "description": "安全计算器（四则/幂/括号/取模），输入数学表达式。",
     "inputSchema": {"type": "object",
                     "properties": {"expression": {"type": "string"}},
                     "required": ["expression"]}},
    {"name": "get_weather",
     "description": "查询某城市当前天气（open-meteo 免 key，返回温度/风速/天气码）。",
     "inputSchema": {"type": "object",
                     "properties": {"city": {"type": "string"},
                                    "units": {"type": "string", "enum": ["celsius", "fahrenheit"]}}}},
]


def _handle(msg: dict) -> dict | None:
    method = msg.get("method")
    if method == "initialize":
        return {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}},
                "serverInfo": {"name": "lifehub-demo", "version": "1.0"}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        params = msg.get("params") or {}
        name = params.get("name")
        args = params.get("arguments") or {}
        if name == "get_current_time":
            res = _now()
        elif name == "roll_dice":
            res = _roll(args.get("dice", "1d6"))
        elif name == "calculator":
            res = _calc(args.get("expression", ""))
        elif name == "get_weather":
            res = _weather(args.get("city", ""), args.get("units", "celsius"))
        else:
            return {"isError": True,
                    "content": [{"type": "text", "text": f"未知工具: {name}"}]}
        if isinstance(res, dict) and "error" in res:
            return {"isError": True,
                    "content": [{"type": "text", "text": json.dumps(res, ensure_ascii=False)}]}
        return {"content": [{"type": "text", "text": json.dumps(res, ensure_ascii=False)}]}
    return None  # 未知方法不响应（客户端侧超时兜底）


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            print(json.dumps({"jsonrpc": "2.0", "id": None,
                              "error": {"code": -32700, "message": "parse error"}},
                             ensure_ascii=False), flush=True)
            continue
        rid = msg.get("id")
        if rid is None:  # 通知（含 notifications/initialized）无响应
            continue
        result = _handle(msg)
        if result is None:
            continue
        print(json.dumps({"jsonrpc": "2.0", "id": rid, "result": result},
                         ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
