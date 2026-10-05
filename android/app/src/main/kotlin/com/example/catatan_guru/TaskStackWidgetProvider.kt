package com.xana.catatan_guru

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.xana.catatan_guru.R
import es.antonborri.home_widget.HomeWidgetProvider

class TaskStackWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (widgetId in appWidgetIds) {
            val serviceIntent = Intent(context, TaskStackRemoteService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            val views = RemoteViews(context.packageName, R.layout.task_stack_widget).apply {
                setRemoteAdapter(R.id.task_stack_view, serviceIntent)
                setTextViewText(R.id.task_count, widgetData.getString("task_count", "0") ?: "0")
                setEmptyView(R.id.task_stack_view, R.id.task_count)

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val pendingIntent = PendingIntent.getActivity(context, 1, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setPendingIntentTemplate(R.id.task_stack_view, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.task_stack_view)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(android.content.ComponentName(context, TaskStackWidgetProvider::class.java))
            for (id in ids) {
                mgr.notifyAppWidgetViewDataChanged(id, R.id.task_stack_view)
            }
        }
    }
}
