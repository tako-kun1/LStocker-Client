package com.example.lstocker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LaunchAppReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        context.startActivity(launchIntent)
    }
}
