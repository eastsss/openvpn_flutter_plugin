class ConnectionInfo {
  ConnectionInfo({
    required this.byteIn,
    required this.byteOut
  });

  ///Downloaded bytes
  final int byteIn;

  ///Uploaded bytes
  final int byteOut;
}
