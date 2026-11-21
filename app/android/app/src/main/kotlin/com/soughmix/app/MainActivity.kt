package com.soughmix.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service 要求宿主 Activity 使用共享 FlutterEngine（后台播放/通知栏控制依赖它）
class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null
    private var mediaChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 把引擎交给原生通知服务，供通知按钮回调 Dart
        MediaNotificationService.appEngine = flutterEngine

        // 播放器后台卡片：Dart 推状态 -> Native 更新通知
        mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soughmix/media").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val intent = Intent(this, MediaNotificationService::class.java).apply {
                            action = MediaNotificationService.ACTION_UPDATE
                            putExtra("title", call.argument<String>("title") ?: "枕声")
                            putExtra("subtitle", call.argument<String>("subtitle") ?: "")
                            putExtra("playing", call.argument<Boolean>("playing") ?: false)
                            putExtra("position", call.argument<Number>("position")?.toLong() ?: 0L)
                            putExtra("duration", call.argument<Number>("duration")?.toLong() ?: 0L)
                        }
                        // startForeground 必须在主线程，避免 MIUI 上抛后台启动异常
                        mainHandler.post {
                            try {
                                startForegroundService(intent)
                            } catch (e: Exception) {
                                // 部分 ROM 禁止后台启动前台服务，退回普通 startService
                                try { startService(intent) } catch (_: Exception) {}
                            }
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        mainHandler.post {
                            stopService(Intent(this, MediaNotificationService::class.java))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soughmix/app").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    // 桌面图标深/浅切换（activity-alias 启停，DONT_KILL_APP 不杀进程）
                    "setLauncherIcon" -> {
                        val theme = call.argument<String>("theme") ?: "dark"
                        applyLauncherIcon(theme)
                        result.success(currentLauncherIcon())
                    }
                    "getLauncherIcon" -> result.success(currentLauncherIcon())
                    // 通知权限状态（媒体通知/锁屏控制依赖它）
                    "notificationsEnabled" -> result.success(notificationsEnabled())
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    // 通知链路诊断：把 ROM 降权/权限/通道状态暴露给 UI，一次性定位
                    "diagnoseNotification" -> result.success(diagnoseNotification())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        mediaChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // audio_service 是懒建通道：只有它真正构建通知时才创建。若 native 侧
        // 还没走到那一步，诊断就显示"通道未创建"。这里显式预建同 ID 的 LOW 通道
        // 兜底（LOW 是 Android 媒体通知标准值，v1.0.0 实际就是这个值），
        // audio_service 的 createChannel() 见通道已存在就不会再用 LOW 覆盖。
        ensureMediaNotificationChannel()
        maybeRequestNotificationPermission()
    }

    private fun ensureMediaNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val id = MediaNotificationService.CHANNEL_ID // com.soughmix.app.playback
        if (nm.getNotificationChannel(id) != null) return
        val channel = NotificationChannel(
            id,
            "混音播放",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "在通知栏与锁屏控制枕声的混音播放"
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    // ---- 桌面图标切换 ----

    private fun applyLauncherIcon(theme: String) {
        val wantLight = theme == "light"
        val enable = if (wantLight) ".LauncherLight" else ".LauncherMain"
        val disable = if (wantLight) ".LauncherMain" else ".LauncherLight"
        val pm = packageManager
        pm.setComponentEnabledSetting(
            ComponentName(this, "$packageName$enable"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            ComponentName(this, "$packageName$disable"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun currentLauncherIcon(): String =
        if (packageManager.getComponentEnabledSetting(ComponentName(this, "$packageName.LauncherLight"))
            == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        ) "light" else "dark"

    // ---- 通知权限（Android 13+ 媒体通知也需要授权才显示） ----

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_SETTINGS)
        }
        startActivity(intent)
    }

    // 读取通知链路真实状态，供设置页诊断展示。importance 含义见 NotificationManager：
    // IMPORTANCE_NONE=0(被关) / MIN=1 / LOW=2(静默，媒体控制常没了) / DEFAULT=3 / HIGH=4
    private fun diagnoseNotification(): Map<String, Any> {
        val nm = getSystemService(NotificationManager::class.java)
        val ch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            nm?.getNotificationChannel(MediaNotificationService.CHANNEL_ID) else null
        // 播放器卡片由 MediaNotificationService 直接 push（id=2001）。
        // 直接问系统"这条通知在不在"，比只看 Dart handler 更能说明卡片到底显示没显示。
        val posted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm?.activeNotifications?.any { it.id == MediaNotificationService.NOTIFICATION_ID } ?: false
        } else false
        return mapOf(
            "sdk" to Build.VERSION.SDK_INT,
            "postPermission" to notificationsEnabled(),
            "notificationsEnabled" to (nm?.areNotificationsEnabled() ?: true),
            "channelExists" to (ch != null),
            "channelImportance" to (ch?.importance ?: -1),
            "channelId" to MediaNotificationService.CHANNEL_ID,
            "notificationPosted" to (posted || MediaNotificationService.lastPosted)
        )
    }

    // Android 13+ 通知权限：未授权则每次启动都询问（此前"只问一次"会因误点拒绝而永久静默；
    // 系统判定"永久拒绝"时 requestPermissions 会静默失败，改由设置页引导跳系统设置）
    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (notificationsEnabled()) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
    }
}
