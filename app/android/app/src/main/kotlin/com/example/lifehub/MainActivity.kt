package com.example.lifehub

import android.graphics.Rect
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// health 插件需要 ComponentActivity。FlutterFragmentActivity 继承该类，
// 同时保留 FlutterActivity 的引擎配置与当前 MethodChannel 能力。
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "lifehub/nav"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 首页按系统返回 → 退到后台不退出（像微信）：进程存活，点开即原位恢复。
        // 由 AppShell 根页 PopScope 拦截后调用。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveTaskToBack" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    // 面板打开期间排除左右缘系统边缘返回手势，让滑动交给应用跟手处理
                    // （否则右滑从屏幕左缘起会被 MIUI/Android 系统劫持成「返回」→ 退桌面）
                    "setEdgeExclusion" -> {
                        val raw = call.argument<List<List<Double>>?>("rects")
                        val density = resources.displayMetrics.density
                        val rects = raw?.map { r ->
                            Rect(
                                (r[0] * density).toInt(),
                                (r[1] * density).toInt(),
                                (r[2] * density).toInt(),
                                (r[3] * density).toInt(),
                            )
                        } ?: emptyList()
                        @Suppress("DEPRECATION")
                        window.setSystemGestureExclusionRects(rects)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
