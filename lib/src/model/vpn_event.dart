import 'package:openvpn_flutter_plugin/openvpn_flutter.dart';

/// Not intended to be used outside of this plugin.
enum VPNEvent {
  NOPROCESS,
  VPN_GENERATE_CONFIG,
  RESOLVE,
  WAIT,
  CONNECTING,
  GET_CONFIG,
  ASSIGN_IP,
  CONNECTED,
  DISCONNECTED,
  DISCONNECTING,
  RECONNECTING,
  AUTH_FAILED;

  static VPNEvent? fromNativeEvent(String name) {
    for (VPNEvent enumVariant in VPNEvent.values) {
      if (enumVariant.name == name) return enumVariant;
    }
    return null;
  }

  VPNState? correspondingState() {
    switch (this) {
      case VPNEvent.NOPROCESS:
      case VPNEvent.DISCONNECTED:
        return VPNState.disconnected;
      case VPNEvent.VPN_GENERATE_CONFIG:
      case VPNEvent.RESOLVE:
      case VPNEvent.WAIT:
      case VPNEvent.CONNECTING:
      case VPNEvent.GET_CONFIG:
      case VPNEvent.ASSIGN_IP:
      case VPNEvent.RECONNECTING:
        return VPNState.connecting;
      case VPNEvent.CONNECTED:
        return VPNState.connected;
      case VPNEvent.DISCONNECTING:
        return VPNState.disconnecting;
      default:
        return null;
    }
  }

  VPNError? correspondingError() {
    switch (this) {
      case VPNEvent.AUTH_FAILED:
        return VPNError.authFailed;
      default:
        return null;
    }
  }
}