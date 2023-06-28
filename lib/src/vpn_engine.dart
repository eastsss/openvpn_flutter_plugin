import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'model/vpn_status.dart';

///Stages of vpn connections
enum VPNState {
  prepare,
  authenticating,
  connecting,
  connected,
  disconnected,
  disconnecting,
  denied,
  error,
// ignore: constant_identifier_names
  wait_connection,
// ignore: constant_identifier_names
  no_connection,
  reconnect
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

  ///To indicate the engine already initialize
  bool initialized = false;

  ///Use tempDateTime to countdown, especially on android that has delays
  DateTime? _tempDateTime;

  /// is a listener to see vpn status detail
  //final Function(VpnStatus? data)? onVpnStatusChanged;

  /// is a listener to see what stage the connection was
  final Function(VPNState stage)? onVpnStateChanged;

  /// OpenVPN's Constructions, don't forget to implement the listeners
  /// onVpnStatusChanged is a listener to see vpn status detail
  /// onVpnStageChanged is a listener to see what stage the connection was
  OpenVPN({/*this.onVpnStatusChanged, */this.onVpnStateChanged});

  ///This function should be called before any usage of OpenVPN
  ///All params required for iOS, make sure you read the plugin's documentation
  ///
  ///
  ///providerBundleIdentfier is for your Network Extension identifier
  ///
  ///localizedDescription is for description to show in user's settings
  ///
  ///
  Future<void> initialize({
    String? providerBundleIdentifier,
    String? localizedDescription,
    String? groupIdentifier/*,
    Function(VpnStatus status)? lastStatus,
    Function(VPNStage status)? lastStage,*/
  }) async {
    if (Platform.isIOS) {
      assert(
          groupIdentifier != null &&
              providerBundleIdentifier != null &&
              localizedDescription != null,
          "These values are required for ios.");
    }
    initialized = true;
    _initializeListener();
    return _methodChannel.invokeMethod("initialize", {
      "groupIdentifier": groupIdentifier,
      "providerBundleIdentifier": providerBundleIdentifier,
      "localizedDescription": localizedDescription,
    })/*.then((value) {
      status().then((value) => lastStatus?.call(value));
      stage().then((value) => lastStage?.call(value));
    })*/;
  }

  ///Connect to VPN
  ///
  ///config : Your openvpn configuration script, you can find it inside your .ovpn file
  ///
  ///name : name that will show in user's notification
  ///
  ///certIsRequired : default is false, if your config file has cert, set it to true
  ///
  ///username & password : set your username and password if your config file has auth-user-pass
  ///
  ///bypassPackages : exclude some apps to access/use the VPN Connection, it was List<String> of applications package's name (Android Only)
  void connect(String config, String name,
      {String? username,
      String? password,
      List<String>? bypassPackages}) async {
    if (!initialized) throw ("OpenVPN need to be initialized");
    _tempDateTime = DateTime.now();
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
    _tempDateTime = null;
    _methodChannel.invokeMethod("disconnect");
  }

  ///Get latest connection stage
  /*Future<VPNState> state() async {
    String? stage = await _methodChannel.invokeMethod("stage");
    return _strToStage(stage ?? "disconnected");
  }*/

  ///Get latest connection status
  /*Future<VpnStatus?> status() {
    //Have to check if user already connected to get real data
    return stage().then((value) async {
      if (value == VPNStage.connected) {
        status = await _methodChannel.invokeMethod("status").then((value) {
          if (value == null) return VpnStatus.empty();

          if (Platform.isIOS) {
            var splitted = value.split("_");
            var connectedOn = DateTime.tryParse(splitted[0]);
            if (connectedOn == null) return VpnStatus.empty();
            return VpnStatus(
              connectedOn: connectedOn,
              duration: _duration(DateTime.now().difference(connectedOn).abs()),
              packetsIn: splitted[1],
              packetsOut: splitted[2],
              byteIn: splitted[3],
              byteOut: splitted[4],
            );
          } else if (Platform.isAndroid) {
            var data = jsonDecode(value);
            var connectedOn =
                DateTime.tryParse(data["connected_on"].toString()) ??
                    _tempDateTime;
            String byteIn =
                data["byte_in"] != null ? data["byte_in"].toString() : "0";
            String byteOut =
                data["byte_out"] != null ? data["byte_out"].toString() : "0";
            if (byteIn.trim().isEmpty) byteIn = "0";
            if (byteOut.trim().isEmpty) byteOut = "0";
            return VpnStatus(
              connectedOn: connectedOn,
              duration:
                  _duration(DateTime.now().difference(connectedOn!).abs()),
              byteIn: byteIn,
              byteOut: byteOut,
              packetsIn: byteIn,
              packetsOut: byteOut,
            );
          } else {
            throw Exception("Openvpn not supported on this platform");
          }
        });
      }
      return null;
    });
  }*/

  ///Convert duration that produced by native side as Connection Time
  String _duration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  ///Private function to convert String to VPNStage
  static VPNState _strToState(String? state) {
    if (state == null ||
        state.trim().isEmpty ||
        state.trim() == "idle" ||
        state.trim() == "invalid") {
      return VPNState.disconnected;
    }
    var indexStage = VPNState.values.indexWhere((element) => element
        .toString()
        .trim()
        .toLowerCase()
        .contains(state.toString().trim().toLowerCase()));
    if (indexStage >= 0) return VPNState.values[indexStage];
    return VPNState.disconnected;
  }

  ///Initialize listener, called when you start connection and stoped while
  void _initializeListener() {
    _stateEventChannel().listen((event) {
      debugPrint("VPNState event received: $event");
      var vpnStage = _strToState(event);
      onVpnStateChanged?.call(vpnStage);
      /*if (vpnStage != VPNStage.disconnected) {
        if (Platform.isAndroid) {
          _createTimer();
        } else if (Platform.isIOS && vpnStage == VPNStage.connected) {
          _createTimer();
        }
      } else {
        _vpnStatusTimer?.cancel();
      }*/
    });
    _connectionInfoEventChannel().listen((event) {
      debugPrint("Connection info event received: $event");
    });
  }

  ///Create timer to invoke status
  /*void _createTimer() {
    if (_vpnStatusTimer != null) {
      _vpnStatusTimer!.cancel();
      _vpnStatusTimer = null;
    }
    _vpnStatusTimer ??=
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      onVpnStatusChanged?.call(await status());
    });
  }*/
}
