package com.soughmix.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * 枕声 · 播放器后台卡片（通知栏 + 锁屏）
 *
 * 不依赖 audio_service 的通知状态机：由 Native 直接建 MediaSessionCompat 并
 * startForeground 推 MediaStyle 通知，Dart 每秒把标题/倒计时/进度推过来，
 * 通知按钮再经 MethodChannel 回调 Dart 的 PlaybackController。
 */
class MediaNotificationService : Service() {

    companion object {
        const val CHANNEL_ID = "com.soughmix.app.playback"
        const val NOTIFICATION_ID = 2001
        const val ACTION_UPDATE = "soughmix.media.UPDATE"
        const val ACTION_STOP = "soughmix.media.STOP"
        const val ACTION_PLAY = "soughmix.media.PLAY"
        const val ACTION_PAUSE = "soughmix.media.PAUSE"
        const val ACTION_NEXT = "soughmix.media.NEXT"
        const val ACTION_PREV = "soughmix.media.PREV"
        /** 媒体按钮全部用 CustomAction：MIUI/HyperOS 会把 CustomAction 排在标准按钮之前，
         *  且按添加顺序渲染。三个按钮统一用 CustomAction，避免标准按钮与自定义按钮混排导致
         *  顺序不可控。退出 X 已按用户要求移除。 */
        // 三个媒体按钮使用系统标准传输控制（PlaybackState actions），
        // 图标尺寸/顺序由 ROM 按播放器规范渲染，不用 CustomAction。
        // （r15/r16 曾把三键做成 CustomAction，MIUI 上图标变大、顺序错乱，已回退。）

        /** MainActivity 就绪后写入，优先于 audio_service 的缓存引擎 */
        @Volatile
        var appEngine: FlutterEngine? = null

        /** 供诊断读取：通知是否已 push */
        @Volatile
        var lastPosted = false
    }

    private var mediaSession: MediaSessionCompat? = null
    private var methodChannel: MethodChannel? = null

    /** 通知/锁屏大图用的品牌 Logo（缓存，避免每秒重绘） */
    private var artBitmap: Bitmap? = null

    private fun loadArt(): Bitmap? {
        artBitmap?.let { return it }
        val d = resources.getDrawable(R.mipmap.ic_launcher, theme) ?: return null
        val size = 256
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(canvas)
        artBitmap = bmp
        return bmp
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()

        mediaSession = MediaSessionCompat(this, "soughmix_media").apply {
            setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS)
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = sendControl("play")
                override fun onPause() = sendControl("pause")
                override fun onStop() = sendControl("stop")
                override fun onSkipToNext() = sendControl("next")
                override fun onSkipToPrevious() = sendControl("prev")
                // 标准传输控制回调即可：上一首/下一首=切方案，播放/暂停/停止如常。
            })
        }

        val engine = appEngine ?: FlutterEngineCache.getInstance().get("audio_service_engine")
        if (engine != null) {
            methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "soughmix/media")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> sendControl("play")
            ACTION_PAUSE -> sendControl("pause")
            ACTION_NEXT -> sendControl("next")
            ACTION_PREV -> sendControl("prev")
            ACTION_STOP -> sendControl("stop")
            ACTION_UPDATE -> {
                val title = intent.getStringExtra("title") ?: "枕声"
                val subtitle = intent.getStringExtra("subtitle") ?: ""
                val playing = intent.getBooleanExtra("playing", false)
                val position = intent.getLongExtra("position", 0L)
                val duration = intent.getLongExtra("duration", 0L)
                post(title, subtitle, playing, position, duration)
            }
            else -> {
                // 无 action 的启动：保持前台服务存活，避免被系统回收
            }
        }
        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            "混音播放",
            NotificationManager.IMPORTANCE_LOW, // 媒体通知标准值：不弹窗、静默、进锁屏
        ).apply {
            description = "在通知栏与锁屏控制枕声的混音播放"
            setShowBadge(false)
        }
        nm.createNotificationChannel(ch)
    }

    private fun post(
        title: String,
        subtitle: String,
        playing: Boolean,
        positionMs: Long,
        durationMs: Long,
    ) {
        val session = mediaSession ?: return

        session.isActive = true
        val art = loadArt()
        val metaBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
        // 专辑封面 = 品牌 Logo。锁屏媒体卡片的大图来自这里，不设的话
        // ROM 会拿一个默认音符图或用法图标拼出"第二个 logo"。
        if (art != null) {
            metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, art)
        }
        session.setMetadata(metaBuilder.build())
        // 三个按钮全部用系统标准传输控制（PlaybackState actions）：
        // 上一首(SKIP_PREVIOUS) · 播放/暂停 · 下一首(SKIP_NEXT)。
        // 标准按钮由 ROM 按播放器规范渲染，图标尺寸统一、顺序固定，不会像
        // CustomAction 那样在 MIUI 上变大/乱序。退出 X 已按用户要求移除。
        val state = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
            .setState(
                if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                positionMs,
                1f,
            )
            .build()
        session.setPlaybackState(state)

        val playPauseIntent = actionIntent(if (playing) ACTION_PAUSE else ACTION_PLAY)
        val nextIntent = actionIntent(ACTION_NEXT)
        val prevIntent = actionIntent(ACTION_PREV)
        val playPauseAction = if (playing) {
            NotificationCompat.Action(
                com.ryanheise.audioservice.R.drawable.audio_service_pause, "暂停", playPauseIntent)
        } else {
            NotificationCompat.Action(
                com.ryanheise.audioservice.R.drawable.audio_service_play_arrow, "播放", playPauseIntent)
        }
        // 按钮顺序：上一首(切方案) · 播放/暂停 · 下一首(切方案)
        // 退出 X 已按用户要求移除，停止播放改由 App 内操作 / 睡眠倒计时渐弱完成。
        val prevAction = NotificationCompat.Action(
            com.ryanheise.audioservice.R.drawable.audio_service_skip_previous, "上一个方案", prevIntent)
        val nextAction = NotificationCompat.Action(
            com.ryanheise.audioservice.R.drawable.audio_service_skip_next, "下一个方案", nextIntent)

        val style = MediaStyle()
            .setMediaSession(session.sessionToken)
            // 收起态按钮：上一首(0) 播放/暂停(1) 下一首(2)
            .setShowActionsInCompactView(0, 1, 2)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            // 小图标用全透明图：系统只校验"有没有 smallIcon"，透明图能让通知
            // 正常显示，同时移除主图右下角那个多余的小 logo（用户明确要求）。
            .setSmallIcon(R.drawable.ic_stat_transparent)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .setStyle(style)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
        // 通知主图（下拉卡片左侧大图）= 品牌 Logo，与锁屏封面一致
        if (art != null) builder.setLargeIcon(art)

        if (durationMs > 0) {
            val p = positionMs.coerceIn(0, durationMs).toInt()
            builder.setProgress(durationMs.toInt(), p, false)
        }

        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        lastPosted = true
    }

    private fun actionIntent(action: String): PendingIntent {
        val intent = Intent(this, MediaNotificationService::class.java).setAction(action)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, action.hashCode(), intent, flags)
    }

    private fun sendControl(action: String) {
        val ch = methodChannel ?: return
        ch.invokeMethod(
            "control",
            mapOf("action" to action),
            object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(code: String, message: String?, details: Any?) {}
                override fun notImplemented() {}
            },
        )
    }

    override fun onDestroy() {
        mediaSession?.let {
            it.isActive = false
            it.release()
        }
        mediaSession = null
        methodChannel = null
        lastPosted = false
        super.onDestroy()
    }
}
