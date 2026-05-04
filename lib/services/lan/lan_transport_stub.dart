import 'lan_types.dart';

LanTransport createLanTransport() => _UnsupportedLanTransport();

class _UnsupportedLanTransport implements LanTransport {
  @override
  bool get supported => false;

  @override
  Future<HostSession> hostGame({required String hostName, int port = 4040}) {
    throw UnsupportedError('LAN sockets are not supported on this platform.');
  }

  @override
  Future<ClientSession> joinGame({
    required String hostIp,
    required String playerName,
    int port = 4040,
  }) {
    throw UnsupportedError('LAN sockets are not supported on this platform.');
  }

  @override
  Future<String?> localIpv4() async => null;
}
