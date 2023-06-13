///To store datas of VPN Connection's status detail
class VpnStatus {
  VpnStatus({
    required this.duration,
    required this.connectedOn,
    required this.byteIn,
    required this.byteOut,
    required this.packetsIn,
    required this.packetsOut,
  });

  ///Latest connection date
  ///Return null if vpn disconnected
  final DateTime connectedOn;

  ///Duration of vpn usage
  final String duration;

  ///Download byte usages
  final String byteIn;

  ///Upload byte usages
  final String byteOut;

  ///Packets in byte usages
  final String packetsIn;

  ///Packets out byte usages
  final String packetsOut;

  ///Convert to JSON
  Map<String, dynamic> toJson() => {
        "connected_on": connectedOn,
        "duration": duration,
        "byte_in": byteIn,
        "byte_out": byteOut,
        "packets_in": packetsIn,
        "packets_out": packetsOut,
      };

  @override
  String toString() => toJson().toString();
}
