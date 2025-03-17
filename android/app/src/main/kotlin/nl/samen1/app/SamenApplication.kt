package nl.samen1.app

import io.flutter.app.FlutterApplication
import androidx.work.Configuration
import android.util.Log

class SamenApplication : FlutterApplication(), Configuration.Provider {
    
    override fun onCreate() {
        super.onCreate()
        Log.i("SamenApplication", "Application onCreate called")
    }
    
    override fun getWorkManagerConfiguration(): Configuration {
        return Configuration.Builder()
            .setMinimumLoggingLevel(android.util.Log.INFO)
            .build()
    }
}
