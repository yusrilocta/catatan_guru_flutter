package com.xana.catatan_guru

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.xana.catatan_guru.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TaskStackRemoteService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskStackFactory(applicationContext)
    }
}

class TaskStackFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var items: JSONArray = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString("task_list", "[]") ?: "[]"
        items = try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    override fun onDestroy() {
        items = JSONArray()
    }

    override fun getCount(): Int = if (items.length() == 0) 1 else items.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.task_stack_item)
        if (items.length() == 0) {
            views.setTextViewText(R.id.task_title, "Tidak ada tugas aktif")
            views.setTextViewText(R.id.task_meta, "Semua tugas selesai")
            views.setTextViewText(R.id.task_deadline, "—")
            views.setTextViewText(R.id.task_status, "")
        } else {
            val safePos = position % items.length()
            val obj = items.getJSONObject(safePos)
            views.setTextViewText(R.id.task_title, obj.optString("title", "-"))
            views.setTextViewText(R.id.task_meta, obj.optString("meta", ""))
            views.setTextViewText(R.id.task_deadline, obj.optString("deadline", ""))
            views.setTextViewText(R.id.task_status, obj.optString("status", ""))
        }
        val fillIntent = Intent()
        views.setOnClickFillInIntent(R.id.task_title, fillIntent)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
