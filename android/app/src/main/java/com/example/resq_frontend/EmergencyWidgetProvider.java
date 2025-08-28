package com.example.resq_frontend;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.widget.RemoteViews;

import es.antonborri.home_widget.HomeWidgetBackgroundReceiver;

public class EmergencyWidgetProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.emergency_widget);

            // 📌 버튼 클릭 → Flutter backgroundCallback 호출
            Intent sendIntent = new Intent(context, HomeWidgetBackgroundReceiver.class);
            sendIntent.setAction("send_emergency");
            sendIntent.setData(Uri.parse("homewidget://send_emergency"));

            PendingIntent sendPendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    sendIntent,
                    PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.emergency_button, sendPendingIntent);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}
