package com.example.resq_frontend;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.widget.RemoteViews;

public class DisasterWidgetProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.disaster_widget);

            // ✅ Flutter → HomeWidget 저장 값 가져오기 (helper 필요)
            boolean hasDisaster = HomeWidgetHelper.getHasDisaster(context);

            if (hasDisaster) {
                views.setTextViewText(R.id.disaster_status_text, "재난 문자가 있습니다!");
                views.setInt(R.id.disaster_status_text, "setBackgroundColor", Color.RED);
            } else {
                views.setTextViewText(R.id.disaster_status_text, "재난 문자가 없습니다");
                views.setInt(R.id.disaster_status_text, "setBackgroundColor", Color.GREEN);
            }

            // ✅ 위젯 전체 클릭 → 앱 열기
            Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.disaster_widget_root, pendingIntent);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}
