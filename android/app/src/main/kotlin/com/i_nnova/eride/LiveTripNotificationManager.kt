package com.i_nnova.eride

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.net.URL

/**
 * Renders the live "driver arriving / heading to destination" trip progress
 * as a custom RemoteViews notification, driven from Flutter every ~10s while
 * a ride/parcel is out-for-pickup or ongoing (see LiveTripNotificationHelper
 * on the Dart side and RideController.remainingDistance()).
 */
object LiveTripNotificationManager {

    private const val TAG = "LiveTripNotification"
    private const val CHANNEL_ID = "trip_progress_channel"
    private const val NOTIFICATION_ID = 9911

    /** Approximate width (dp) of the progress track's flexible middle segment.
     * RemoteViews can't be measured before being shown, so on API 31+ (where we can
     * reposition the vehicle icon precisely) we position it against this assumed
     * width; this is a close visual approximation, not pixel-exact. */
    private const val ASSUMED_TRACK_WIDTH_DP = 220f
    private const val TRACK_ICON_WIDTH_DP = 34f

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastAvatarUrl: String? = null
    private var lastAvatarBitmap: Bitmap? = null
    private var lastVehicleUrl: String? = null
    private var lastVehicleBitmap: Bitmap? = null

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Trip progress",
                    NotificationManager.IMPORTANCE_LOW
                )
                channel.description = "Live driver arrival / trip progress updates"
                channel.setShowBadge(false)
                manager.createNotificationChannel(channel)
            }
        }
    }

    fun showOrUpdate(context: Context, data: Map<*, *>) {
        Log.d(TAG, "showOrUpdate called: $data")
        ensureChannel(context)

        val avatarUrl = (data["avatarUrl"] as? String).orEmpty()
        val vehicleUrl = (data["vehicleImageUrl"] as? String).orEmpty()

        val needAvatar = avatarUrl.isNotEmpty() && avatarUrl != lastAvatarUrl
        val needVehicle = vehicleUrl.isNotEmpty() && vehicleUrl != lastVehicleUrl

        if (needAvatar || needVehicle) {
            Thread {
                if (needAvatar) {
                    downloadRoundedSquareBitmap(avatarUrl)?.let {
                        lastAvatarUrl = avatarUrl
                        lastAvatarBitmap = it
                    }
                }
                if (needVehicle) {
                    downloadBitmap(vehicleUrl)?.let {
                        lastVehicleUrl = vehicleUrl
                        lastVehicleBitmap = it
                    }
                }
                mainHandler.post { render(context, data) }
            }.start()
        } else {
            render(context, data)
        }
    }

    fun stop(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        lastAvatarUrl = null
        lastAvatarBitmap = null
        lastVehicleUrl = null
        lastVehicleBitmap = null
    }

    private fun render(context: Context, data: Map<*, *>) {
        val title = (data["title"] as? String).orEmpty()
        val subtitle = (data["subtitle"] as? String).orEmpty()
        val driverName = (data["driverName"] as? String).orEmpty()
        val vehicleModel = (data["vehicleModel"] as? String).orEmpty()
        val plateNumber = (data["plateNumber"] as? String).orEmpty()
        val vehicleType = (data["vehicleType"] as? String).orEmpty()
        val progress = (data["progress"] as? Double)?.toFloat()
            ?: (data["progress"] as? Number)?.toFloat() ?: 0f

        val isCar = vehicleType.contains("car", ignoreCase = true)
        // Teal glyph — the card is white; only the header icon sits on a teal background.
        val vehicleIconRes = if (isCar) R.drawable.ic_trip_car_teal else R.drawable.ic_trip_scooter_teal

        val vehicleInfo = listOf(vehicleModel, plateNumber).filter { it.isNotEmpty() }.joinToString("  •  ")
        val clampedProgress = progress.coerceIn(0f, 1f)

        // A RemoteViews instance is consumed when attached to a notification, so the
        // collapsed and expanded slots each need their own freshly-built instance.
        val vehicle = lastVehicleBitmap

        fun buildViews(): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.notification_trip_progress)
            views.setTextViewText(R.id.tv_title, title)
            views.setTextViewText(R.id.tv_subtitle, subtitle)
            // iv_phase_icon stays the app logo (set in the layout) — only the track
            // and badge slots reflect the vehicle.
            if (vehicle != null) {
                views.setImageViewBitmap(R.id.iv_track_vehicle_icon, vehicle)
                views.setImageViewBitmap(R.id.iv_vehicle_type_icon, vehicle)
            } else {
                views.setImageViewResource(R.id.iv_track_vehicle_icon, vehicleIconRes)
                views.setImageViewResource(R.id.iv_vehicle_type_icon, vehicleIconRes)
            }

            views.setTextViewText(R.id.tv_driver_name, driverName)
            views.setTextViewText(R.id.tv_vehicle_info, vehicleInfo)

            val avatar = lastAvatarBitmap
            if (avatar != null) {
                views.setImageViewBitmap(R.id.iv_driver_avatar, avatar)
            } else {
                views.setImageViewResource(R.id.iv_driver_avatar, R.drawable.ic_trip_avatar_placeholder)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setViewVisibility(R.id.progress_track, android.view.View.GONE)
                views.setViewVisibility(R.id.iv_track_vehicle_icon, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.track_line_completed, android.view.View.VISIBLE)

                val iconLeadingDp = (ASSUMED_TRACK_WIDTH_DP - TRACK_ICON_WIDTH_DP) * clampedProgress
                views.setViewLayoutMargin(
                    R.id.iv_track_vehicle_icon,
                    RemoteViews.MARGIN_START,
                    iconLeadingDp.coerceAtLeast(0f),
                    TypedValue.COMPLEX_UNIT_DIP
                )
                // Teal completed dashes run from the start up to the icon's center.
                val completedDp = (iconLeadingDp + TRACK_ICON_WIDTH_DP / 2f).coerceIn(0f, ASSUMED_TRACK_WIDTH_DP)
                views.setViewLayoutWidth(R.id.track_line_completed, completedDp, TypedValue.COMPLEX_UNIT_DIP)
            } else {
                views.setViewVisibility(R.id.iv_track_vehicle_icon, android.view.View.GONE)
                views.setViewVisibility(R.id.track_line_completed, android.view.View.GONE)
                views.setViewVisibility(R.id.progress_track, android.view.View.VISIBLE)
                views.setProgressBar(R.id.progress_track, 100, (clampedProgress * 100).toInt(), false)
            }
            return views
        }

        val notificationManager = NotificationManagerCompat.from(context)
        if (!notificationManager.areNotificationsEnabled()) {
            Log.w(TAG, "Notifications are DISABLED for this app — POST_NOTIFICATIONS not granted. Nothing will show.")
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setColor(0xFF00A08D.toInt())
            .setCustomContentView(buildViews())
            .setCustomBigContentView(buildViews())
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)

        try {
            notificationManager.notify(NOTIFICATION_ID, builder.build())
            Log.d(TAG, "notify() posted id=$NOTIFICATION_ID progress=$clampedProgress")
        } catch (e: Exception) {
            Log.e(TAG, "notify() failed: ${e.message}", e)
        }
    }

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            val input = URL(url).openStream()
            val source = BitmapFactory.decodeStream(input)
            input.close()
            source
        } catch (e: Exception) {
            Log.e(TAG, "downloadBitmap failed for $url: ${e.message}")
            null
        }
    }

    private fun downloadRoundedSquareBitmap(url: String): Bitmap? {
        return downloadBitmap(url)?.let { toRoundedSquareBitmap(it) }
    }

    /** Center-crops [source] to a square and applies a small corner radius
     * (square, not circular). */
    private fun toRoundedSquareBitmap(source: Bitmap): Bitmap {
        val size = minOf(source.width, source.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = Rect(0, 0, size, size)
        val rectF = RectF(rect)
        val radius = size * 0.14f

        canvas.drawARGB(0, 0, 0, 0)
        canvas.drawRoundRect(rectF, radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        val srcX = (source.width - size) / 2
        val srcY = (source.height - size) / 2
        canvas.drawBitmap(source, Rect(srcX, srcY, srcX + size, srcY + size), rect, paint)
        return output
    }
}
