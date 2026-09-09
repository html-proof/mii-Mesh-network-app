package app.miimesh.mii_mesh

import android.app.*
import android.content.Intent
import android.os.IBinder

/** Keeps the existing Flutter process available while the user enables mesh. */
class MeshForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("mesh", "Nearby messaging", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        startForeground(2026, Notification.Builder(this, "mesh")
            .setSmallIcon(R.drawable.mii_icon).setContentTitle("Mii Mesh is available")
            .setContentText("Finding nearby people. Pause in Mii Mesh settings.")
            .setContentIntent(open).setOngoing(true).build())
        return START_NOT_STICKY
    }
}
