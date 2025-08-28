package com.example.resq_frontend;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;

public class HomeWidgetHelper {
    public static boolean getHasDisaster(Context context) {
        SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
        return prefs.getBoolean("has_disaster", false);
    }
}
