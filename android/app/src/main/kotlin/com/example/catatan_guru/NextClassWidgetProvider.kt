package com.xana.catatan_guru

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.xana.catatan_guru.R
import es.antonborri.home_widget.HomeWidgetProvider

class NextClassWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_class_widget).apply {
                setTextViewText(R.id.widget_subject, widgetData.getString("next_subject", "Tidak ada jadwal hari ini") ?: "Tidak ada jadwal hari ini")
                val cls = widgetData.getString("next_class", "—") ?: "—"
                val subject = widgetData.getString("next_subject", "") ?: ""
                if (subject.isNotEmpty() && subject != "Tidak ada jadwal hari ini") {
                    setTextViewText(R.id.widget_subject, "$subject — $cls")
                }
                setTextViewText(R.id.widget_school, widgetData.getString("next_school", "") ?: "")
                setTextViewText(R.id.widget_time, widgetData.getString("next_time", "") ?: "")
                setTextViewText(R.id.widget_date, widgetData.getString("next_date", "") ?: "")

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setOnClickPendingIntent(R.id.widget_subject, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
