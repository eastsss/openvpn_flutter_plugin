import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter_plugin/src/model/connection_statistics.dart';

///Stages of vpn connections
enum VPNState {
  noprocess,
  vpn_generate_config,
  resolve,
  wait,
  connecting,
  get_config,
  assign_ip,
  connected,
  disconnected,
  disconnecting,
  reconnecting
}

class OpenVPN {
  static const String _eventChannelVpnState = "com.polecat.openvpn_flutter/vpnstate";
  static const String _eventChannelConnectionInfo = "com.polecat.openvpn_flutter/connectioninfo";
  static const String _methodChannelVpnControl = "com.polecat.openvpn_flutter/vpncontrol";

  ///Method channel to invoke methods from native side
  static const MethodChannel _methodChannel =
      MethodChannel(_methodChannelVpnControl);

  ///Snapshot of stream with events produced by native side
  static Stream<String> _stateEventChannel() => const EventChannel(_eventChannelVpnState).receiveBroadcastStream().cast();
  static Stream<String> _connectionInfoEventChannel() => const EventChannel(_eventChannelConnectionInfo).receiveBroadcastStream().cast();

  Timer? _connectionTimer;
  DateTime? _connectedOn;

  final Function(ConnectionStatistics info)? onConnectionInfoChanged;
  final Function(VPNState state)? onVpnStateChanged;
  final Function(String duration)? onConnectionTimeUpdated;

  OpenVPN({this.onConnectionInfoChanged, this.onVpnStateChanged, this.onConnectionTimeUpdated});

  ///This function should be called before any usage of OpenVPN
  ///All params required for iOS, make sure you read the plugin's documentation
  ///
  ///providerBundleIdentfier is for your Network Extension identifier
  ///
  ///localizedDescription is for description to show in user's settings
  ///
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

  ///Connect to VPN
  ///
  ///config : Your openvpn configuration script, you can find it inside your .ovpn file
  ///
  ///name : name that will show in user's notification
  ///
  ///username & password : set your username and password if your config file has auth-user-pass
  ///
  ///bypassPackages : exclude some apps to access/use the VPN Connection, it was List<String> of applications package's name (Android Only)
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

  ///Disconnect from VPN
  void disconnect() {
    _connectedOn = null;
    _methodChannel.invokeMethod("disconnect");
  }

  void startConnectionTimeUpdates() {
    if (_connectionTimer != null) {
      _connectionTimer?.cancel();
      _connectionTimer = null;
    }
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      var duration = _duration(DateTime.now().difference(_connectedOn!).abs());
      onConnectionTimeUpdated?.call(duration);
    });
  }

  void stopConnectionTimeUpdates() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  void _initializeListeners() {
    _stateEventChannel().listen((event) {
      debugPrint("VPNState event received: $event");
      var vpnState = _strToState(event);
      if (vpnState == VPNState.disconnected) {
        _connectionTimer?.cancel();
        _connectionTimer = null;
        _connectedOn = null;
      }
      onVpnStateChanged?.call(vpnState);
    });
    _connectionInfoEventChannel().listen((event) {
      debugPrint("ConnectionStatistics event received: $event");
      var splitted = event.split("_");
      var info = ConnectionStatistics(
          byteIn: int.parse(splitted[0]),
          byteOut: int.parse(splitted[1])
      );
      onConnectionInfoChanged?.call(info);
    });
  }

  ///Private function to convert String to VPNState
  VPNState _strToState(String? state) {
    if (state == null || state.trim().isEmpty) {
      return VPNState.disconnected;
    }
    var index = VPNState.values.indexWhere((element) => element
        .toString()
        .trim()
        .toLowerCase()
        .contains(state.toString().trim().toLowerCase()));
    if (index >= 0) return VPNState.values[index];
    return VPNState.disconnected;
  }

  String _duration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
