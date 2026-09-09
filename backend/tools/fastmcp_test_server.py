"""WS4 互操作测试服务器：官方 FastMCP SDK 实现，证明纯 stdlib 客户端能真互通。

仅测试期使用（需 pip install mcp fastmcp）。本文件作为子进程由 e2e_mcp_interop.py 拉起。
"""
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("fastmcp-test")


@mcp.tool()
def add(a: int, b: int) -> int:
    """两个整数相加"""
    return a + b


@mcp.tool()
def get_text() -> str:
    """返回一段固定文本"""
    return "hello-from-fastmcp"


if __name__ == "__main__":
    mcp.run(transport="stdio")
