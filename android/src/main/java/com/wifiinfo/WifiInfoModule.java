package com.wifiinfo;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class WifiInfoModule extends ReactContextBaseJavaModule implements LifecycleEventListener {

    private static final String EVENT_WIFI_INFO_CHANGED = "onWifiInfoChanged";
    private final ReactApplicationContext reactContext;
    private final WifiManager wifiManager;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Runnable runnable;
    private WritableMap lastWifiInfo = null;
    private boolean isObserving = false;
    private static final long POLL_INTERVAL = 1000L; // 1秒
    private int observerCount = 0;
    private final Object lock = new Object();

    public WifiInfoModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        this.wifiManager = (WifiManager) reactContext.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        reactContext.addLifecycleEventListener(this);
    }

    @NonNull
    @Override
    public String getName() {
        return "WifiInfo";
    }

    @ReactMethod
    public void startObserve() {
        synchronized (lock) {
            observerCount++;
            if (observerCount > 1)
                return;

            isObserving = true;
            runnable = new Runnable() {
                @Override
                public void run() {
                    if (!hasLocationPermission() || wifiManager == null) {
                        scheduleNext();
                        return;
                    }
                    WritableMap currentInfo = getCurrentWifiInfo();
                    if (!currentInfo.equals(lastWifiInfo)) {
                        lastWifiInfo = currentInfo;
                        sendEvent(currentInfo);
                    }
                    scheduleNext();
                }
            };
            handler.post(runnable);
        }
    }

    @ReactMethod
    public void stopObserve() {
        synchronized (lock) {
            if (observerCount > 0) {
                observerCount--;
                if (observerCount == 0) {
                    isObserving = false;
                    handler.removeCallbacks(runnable);
                    runnable = null;
                }
            }
        }
    }

    private void scheduleNext() {
        if (isObserving && handler != null && runnable != null) {
            handler.postDelayed(runnable, POLL_INTERVAL);
        }
    }

    private boolean hasLocationPermission() {
        return ContextCompat.checkSelfPermission(reactContext,
                Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    @ReactMethod
    public void getCurrentWifiInfo(Promise promise) {
        if (!hasLocationPermission() || wifiManager == null) {
            promise.resolve(null);
            return;
        }
        WritableMap info = getCurrentWifiInfo();
        promise.resolve(info);
    }

    private WritableMap getCurrentWifiInfo() {
        WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        WritableMap map = Arguments.createMap();

        if (wifiInfo == null || wifiInfo.getBSSID() == null) {
            map.putString("ssid", "");
            map.putString("bssid", "");
            map.putString("ip", "");
            return map;
        }

        String ssid = wifiInfo.getSSID();
        if (ssid != null) {
            ssid = ssid.replace("\"", ""); // 去掉引号
        } else {
            ssid = "";
        }

        int ipInt = wifiInfo.getIpAddress();
        @SuppressLint("DefaultLocale") String ip = String.format("%d.%d.%d.%d",
                (ipInt & 0xff),
                (ipInt >> 8 & 0xff),
                (ipInt >> 16 & 0xff),
                (ipInt >> 24 & 0xff));

        map.putString("ssid", ssid);
        map.putString("bssid", wifiInfo.getBSSID());
        map.putString("ip", ip);

        return map;
    }

    private void sendEvent(WritableMap params) {
        if (reactContext.hasActiveReactInstance()) {
            reactContext
                    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                    .emit(WifiInfoModule.EVENT_WIFI_INFO_CHANGED, copyMap(params));
        }
    }

    private WritableMap copyMap(ReadableMap source) {
        WritableMap copy = Arguments.createMap();
        copy.merge(source);
        return copy;
    }

    @Override
    public void onHostResume() {
      // 应用进入前台
    }

    @Override
    public void onHostPause() {
      // 应用进入后台
    }

    @Override
    public void onHostDestroy() {
        stopObserve();
    }
}
