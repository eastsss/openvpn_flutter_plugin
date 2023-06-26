package com.polecat.openvpn_flutter;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;

import androidx.annotation.NonNull;

import java.util.ArrayList;

import de.blinkt.openvpn.OnVPNStatusChangeListener;
import de.blinkt.openvpn.VPNHelper;
import de.blinkt.openvpn.core.OpenVPNService;
import de.blinkt.openvpn.core.StatusListener;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

/**
 * OpenvpnFlutterPlugin
 */
public class OpenVPNFlutterPlugin implements FlutterPlugin, ActivityAware {

    private MethodChannel vpnControlMethod;

    private EventChannel vpnStageEvent;
    private EventChannel.EventSink vpnStageSink;

    private EventChannel vpnStatusEvent;
    private EventChannel.EventSink vpnStatusSink;

    private static final String EVENT_CHANNEL_VPN_STAGE = "com.polecat.openvpn_flutter/vpnstage";
    private static final String EVENT_CHANNEL_VPN_STATUS = "com.polecat.openvpn_flutter/vpnstatus";
    private static final String METHOD_CHANNEL_VPN_CONTROL = "com.polecat.openvpn_flutter/vpncontrol";

    private static String config = "", username = "", password = "", name = "";

    private static ArrayList<String> bypassPackages;
    @SuppressLint("StaticFieldLeak")
    private static VPNHelper vpnHelper;
    //private static StatusListener statusListener;
    private Activity activity;

    Context mContext;


    public static void connectWhileGranted(boolean granted) {
        if (granted) {
            vpnHelper.startVPN(config, username, password, name, bypassPackages);
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        vpnStageEvent = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL_VPN_STAGE);
        vpnStatusEvent = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL_VPN_STATUS);
        vpnControlMethod = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL_VPN_CONTROL);

        vpnStageEvent.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                vpnStageSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                if (vpnStageSink != null) vpnStageSink.endOfStream();
            }
        });

        vpnStatusEvent.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                vpnStatusSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                if (vpnStatusSink != null) vpnStatusSink.endOfStream();
            }
        });

        vpnControlMethod.setMethodCallHandler((call, result) -> {

            switch (call.method) {
                case "status":
                    if (vpnHelper == null) {
                        result.error("-1", "VPNEngine need to be initialize", "");
                        return;
                    }
                    result.success(vpnHelper.status.toString());
                    break;
                case "initialize":
                    vpnHelper = new VPNHelper(activity);
                    /*statusListener = new StatusListener();
                    statusListener.init(binding.getApplicationContext());*/
                    vpnHelper.setOnVPNStatusChangeListener(new OnVPNStatusChangeListener() {
                        @Override
                        public void onVPNStatusChanged(String status) {
                            updateStage(status);
                        }

                        @Override
                        public void onConnectionStatusChanged(String duration, String lastPacketReceive, String byteIn, String byteOut) {
                            updateStatus(vpnHelper.status.toString());
                        }
                    });
                    result.success(getVPNStage());
                    break;
                case "disconnect":
                    if (vpnHelper == null)
                        result.error("-1", "VPNEngine need to be initialize", "");

                    vpnHelper.stopVPN();
                    updateStage("disconnected");
                    break;
                case "connect":
                    if (vpnHelper == null) {
                        result.error("-1", "VPNEngine need to be initialize", "");
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

                    final Intent permission = VpnService.prepare(activity);
                    if (permission != null) {
                        activity.startActivityForResult(permission, 24);
                        return;
                    }
                    vpnHelper.startVPN(config, username, password, name, bypassPackages);
                    break;
                case "stage":
                    if (vpnHelper == null) {
                        result.error("-1", "VPNEngine need to be initialize", "");
                        return;
                    }
                    result.success(getVPNStage());
                    break;
                case "request_permission":
                    final Intent request = VpnService.prepare(activity);
                    if (request != null) {
                        activity.startActivityForResult(request, 24);
                        result.success(false);
                        return;
                    }
                    result.success(true);
                    break;

                default:
            }
        });
        mContext = binding.getApplicationContext();
    }

    public void updateStage(String stage) {
        if (stage == null) stage = "idle";
        if (vpnStageSink != null) vpnStageSink.success(stage.toLowerCase());
    }

    public void updateStatus(String status) {
        if (vpnStatusSink != null && status != null) vpnStatusSink.success(status.toLowerCase());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        vpnStageEvent.setStreamHandler(null);
        vpnStatusEvent.setStreamHandler(null);
        vpnControlMethod.setMethodCallHandler(null);
    }

    private String getVPNStage() {
        if (OpenVPNService.getStatus() == null) {
            OpenVPNService.setDefaultStatus();
        }
        updateStage(OpenVPNService.getStatus());
        return OpenVPNService.getStatus();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {

    }
}
