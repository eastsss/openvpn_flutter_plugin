import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter_plugin/src/model/connection_statistics.dart';
import 'package:openvpn_flutter_plugin/src/model/vpn_event.dart';

enum VPNState {
  connecting, disconnecting, connected, disconnected;
}

enum VPNError {
  authFailed;
}

class OpenVPN {
  static const String _eventChannelVpnEvent = "com.polecat.openvpn_flutter/vpnevent";
  static const String _eventChannelConnectionInfo = "com.polecat.openvpn_flutter/connectioninfo";
  static const String _methodChannelVpnControl = "com.polecat.openvpn_flutter/vpncontrol";

  ///Method channel to invoke methods from native side
  static const MethodChannel _methodChannel =
      MethodChannel(_methodChannelVpnControl);

  ///Snapshot of stream with events produced by native side
  static Stream<String> _vpnEventChannel() => const EventChannel(_eventChannelVpnEvent).receiveBroadcastStream().cast();
  static Stream<String> _connectionInfoEventChannel() => const EventChannel(_eventChannelConnectionInfo).receiveBroadcastStream().cast();

  Timer? _connectionTimer;
  DateTime? _connectedOn;

  final Function(ConnectionStatistics info)? onConnectionInfoChanged;
  final Function(VPNState state)? onVpnStateChanged;
  final Function(VPNError error)? onVpnErrorReceived;
  final Function(String duration)? onConnectionTimeUpdated;

  OpenVPN({
    this.onConnectionInfoChanged,
    this.onVpnStateChanged,
    this.onVpnErrorReceived,
    this.onConnectionTimeUpdated
  });

  ///This function should be called before any usage of OpenVPN
  Future<void> initialize({
    String? providerBundleIdentifier,
    String? localizedDescription,
    String? groupIdentifier
  }) async {
    if (Platform.isIOS) {
      assert(
          groupIdentifier != null &&
              providerBundleIdentifier != null &&
              localizedDescription != null,
          "These values are required for ios.");
    }
    _initializeListeners();
    return _methodChannel.invokeMethod("initialize", {
      "groupIdentifier": groupIdentifier,
      "providerBundleIdentifier": providerBundleIdentifier,
      "localizedDescription": localizedDescription,
    });
  }

  void connect(String config, String name,
      {String? username,
      String? password,
      List<String>? bypassPackages}) async {
    _connectedOn = DateTime.now();
    _methodChannel.invokeMethod("connect", {
      "config": config,
      "name": name,
      "username": username,
      "password": password,
      "bypass_packages": bypassPackages ?? []
    });
  }

  void disconnect() {
    _connectedOn = null;
    _methodChannel.invokeMethod("disconnect");
  }

  String startConnectionTimeUpdates() {
    if (_connectionTimer != null) {
      _connectionTimer?.cancel();
      _connectionTimer = null;
    }
    
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      var duration = _duration(DateTime.now().difference(_connectedOn!).abs());
      onConnectionTimeUpdated?.call(duration);
    });

    return _duration(DateTime.now().difference(_connectedOn!).abs());
  }

  void stopConnectionTimeUpdates() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  /// Private methods
  void _initializeListeners() {
    _vpnEventChannel().listen((event) {
      _handleVPNEvent(event);
    });
    _connectionInfoEventChannel().listen((event) {
      _handleConnectionInfoEvent(event);
    });
  }

  String _duration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _handleVPNEvent(String event) {
    debugPrint("VPNEvent received: $event");
    var vpnEvent = VPNEvent.fromNativeEvent(event);
    if (vpnEvent == VPNEvent.DISCONNECTED) {
      _connectionTimer?.cancel();
      _connectionTimer = null;
      _connectedOn = null;
    }

    var vpnState = vpnEvent?.correspondingState();
    if (vpnState != null) {
      onVpnStateChanged?.call(vpnState);
    }

    var vpnError = vpnEvent?.correspondingError();
    if (vpnError != null) {
      onVpnErrorReceived?.call(vpnError);
    }
  }

  void _handleConnectionInfoEvent(String event) {
    debugPrint("ConnectionStatistics received: $event");
    var splitted = event.split("_");
    var info = ConnectionStatistics(
        byteIn: int.parse(splitted[0]),
        byteOut: int.parse(splitted[1])
    );
    onConnectionInfoChanged?.call(info);
  }
}
