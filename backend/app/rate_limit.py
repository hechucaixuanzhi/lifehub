"""轻量内存限流（按 device_id + 路径，滑动窗口）。

不引入 slowapi 依赖（家用单机场景，纯内存足够；重启即重置）。
对齐 API.md §3.2：超限返回 429 RATE_LIMITED。
"""
import time
from collections import defaultdict, deque
from threading import Lock

_lock = Lock()
# key -> deque[timestamp_ms]（保留窗口内的时间戳）
_buckets: dict[str, deque[float]] = defaultdict(deque)

# 窗口内最大请求数
MAX_REQUESTS = 30
WINDOW_SECONDS = 60


def check_rate_limit(key: str, max_requests: int = MAX_REQUESTS, window: int = WINDOW_SECONDS) -> bool:
    """返回 False 表示超限。key 通常为 f"{device_id}:{path}"。"""
    now = time.time()
    with _lock:
        q = _buckets[key]
        # 清理窗口外的旧时间戳
        while q and q[0] < now - window:
            q.popleft()
        if len(q) >= max_requests:
            return False
        q.append(now)
        return True
