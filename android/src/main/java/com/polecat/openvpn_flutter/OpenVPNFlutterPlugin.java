package com.polecat.openvpn_flutter;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;

import androidx.annotation.NonNull;

import java.util.ArrayList;

import de.blinkt.openvpn.OnVPNStatusChangeListener;
import de.blinkt.openvpn.VPNManager;
import de.blinkt.openvpn.core.OpenVPNService;
import de.blinkt.openvpn.core.StatusListener;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * OpenvpnFlutterPlugin
 */
public class OpenVPNFlutterPlugin implements FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {

    private final String METHOD_CHANNEL_VPN_CONTROL = "com.polecat.openvpn_flutter/vpncontrol";
    private MethodChannel vpnControlMethod;

    private final String EVENT_CHANNEL_VPN_STATE = "com.polecat.openvpn_flutter/vpnstate";
    private EventChannel vpnStateEvent;
    private EventChannel.EventSink vpnStateSink;

    private final String EVENT_CHANNEL_CONNECTION_INFO = "com.polecat.openvpn_flutter/connectioninfo";
    private EventChannel connectionInfoEvent;
    private EventChannel.EventSink connectionInfoSink;

    private final int VPN_PERMISSION_CODE = 24;

    private String config = "", name = "", username = "", password = "";
    private ArrayList<String> bypassPackages;

    private VPNManager vpnManager;
    private ActivityPluginBinding activityBinding;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        vpnControlMethod = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL_VPN_CONTROL);

        vpnStateEvent = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL_VPN_STATE);
        connectionInfoEvent = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL_CONNECTION_INFO);

        vpnStateEvent.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                vpnStateSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                if (vpnStateSink != null) vpnStateSink.endOfStream();
            }
        });

        connectionInfoEvent.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                connectionInfoSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                if (connectionInfoSink != null) connectionInfoSink.endOfStream();
            }
        });

        vpnControlMethod.setMethodCallHandler((call, result) -> {

            switch (call.method) {
                case "initialize":
                    vpnManager = new VPNManager(activityBinding.getActivity());
                    vpnManager.setOnVPNStatusChangeListener(new OnVPNStatusChangeListener() {
                        @Override
                        public void onVPNStateChanged(String state) {
                            updateState(state);
                        }

                        @Override
                        public void onConnectionInfoChanged(long byteIn, long byteOut) {
                            updateConnectionInfo(byteIn, byteOut);
                        }
                    });
                    result.success(null);
                    break;
                case "disconnect":
                    if (vpnManager == null)
                        result.error("-1", "VPNEngine need to be initialized", "");

                    vpnManager.disconnect();
                    result.success(null);
                    break;
                case "connect":
                    if (vpnManager == null) {
                        result.error("-1", "VPNEngine need to be initialized", "");
                        return;
                    }

                    config = call.argument("config");
                    name = call.argument("name");
                    username = call.argument("username");
                    password = call.argument("password");
                    bypassPackages = call.argument("bypass_packages");

                    if (config == null) {
                        result.error("-2", "OpenVPN Config is required", "");
                        return;
                    }

                    Activity activity = activityBinding.getActivity();
                    if (activity == null) {
                        result.error("-3", "Activity binding got null", "");
                    }

                    final Intent permission = vpnManager.getPermissionIntent(activity);
                    if (permission != null) {
                        activity.startActivityForResult(permission, VPN_PERMISSION_CODE);
                    } else {
                        vpnManager.connect(activity, config, name, username, password, bypassPackages);
                    }
                    result.success(null);
                    break;
                default:
                    break;
            }
        });
    }

    public void updateState(String state) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (vpnStateSink != null) vpnStateSink.success(state);
            }
        });
    }

    public void updateConnectionInfo(long byteIn, long byteOut) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                String status = String.format("%d_%d", byteIn, byteOut);
                if (connectionInfoSink != null) connectionInfoSink.success(status);
            }
        });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        vpnStateEvent.setStreamHandler(null);
        connectionInfoEvent.setStreamHandler(null);
        vpnControlMethod.setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        attachActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        attachActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachActivity();
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == VPN_PERMISSION_CODE && resultCode == Activity.RESULT_OK) {
            vpnManager.connect(activityBinding.getActivity(), config, name, username, password, bypassPackages);
            return true;
        } else {
            return false;
        }
    }

    private void attachActivity(ActivityPluginBinding binding) {
        activityBinding = binding;
        activityBinding.addActivityResultListener(this);
        vpnManager.bindVpnService(activityBinding.getActivity());
    }

    private void detachActivity() {
        vpnManager.unbindVpnService(activityBinding.getActivity());
        activityBinding.removeActivityResultListener(this);
        activityBinding = null;
    }

    private void runOnUiThread(Runnable runnable) {
        Activity activity = activityBinding.getActivity();
        if (activity != null) {
            activity.runOnUiThread(runnable);
        }
    }
}
