class LanJoinCodeService {
  static const _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _group = 4;
  static const _defaultPort = 4040;

  static String? encode({
    required String hostIp,
    required int port,
  }) {
    final octets = _parseIpv4(hostIp);
    if (octets == null) return null;
    if (port != _defaultPort) return null;

    final bytes = <int>[
      ...octets,
    ];
    final checksum = bytes.fold<int>(0, (sum, b) => (sum + b) & 0xFF);
    bytes.add(checksum);

    var value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }

    final chars = <String>[];
    while (value > BigInt.zero) {
      final idx = (value % BigInt.from(32)).toInt();
      chars.add(_alphabet[idx]);
      value = value >> 5;
    }
    while (chars.length < 8) {
      chars.add(_alphabet[0]);
    }
    final raw = chars.reversed.join();
    return _format(raw);
  }

  static ({String hostIp, int port})? decode(String code) {
    final normalized = _normalize(code);
    if (normalized.length == 8) {
      return _decodeCompact(normalized);
    }
    if (normalized.length == 12) {
      return _decodeLegacy(normalized);
    }
    return null;
  }

  static ({String hostIp, int port})? _decodeCompact(String normalized) {
    var value = BigInt.zero;
    for (final ch in normalized.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) return null;
      value = (value << 5) | BigInt.from(idx);
    }

    final bytes = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      bytes[i] = (value & BigInt.from(0xFF)).toInt();
      value = value >> 8;
    }

    final checksum = bytes.sublist(0, 4).fold<int>(0, (sum, b) => (sum + b) & 0xFF);
    if (checksum != bytes[4]) return null;

    final hostIp = '${bytes[0]}.${bytes[1]}.${bytes[2]}.${bytes[3]}';
    return (hostIp: hostIp, port: _defaultPort);
  }

  static ({String hostIp, int port})? _decodeLegacy(String normalized) {
    var value = BigInt.zero;
    for (final ch in normalized.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) return null;
      value = (value << 5) | BigInt.from(idx);
    }

    final bytes = List<int>.filled(7, 0);
    for (var i = 6; i >= 0; i--) {
      bytes[i] = (value & BigInt.from(0xFF)).toInt();
      value = value >> 8;
    }

    final checksum = bytes.sublist(0, 6).fold<int>(0, (sum, b) => (sum + b) & 0xFF);
    if (checksum != bytes[6]) return null;

    final hostIp = '${bytes[0]}.${bytes[1]}.${bytes[2]}.${bytes[3]}';
    final port = (bytes[4] << 8) | bytes[5];
    return (hostIp: hostIp, port: port);
  }

  static List<int>? _parseIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final p in parts) {
      final value = int.tryParse(p);
      if (value == null || value < 0 || value > 255) return null;
      octets.add(value);
    }
    return octets;
  }

  static String _normalize(String code) {
    return code.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
  }

  static String _format(String raw) {
    final chunks = <String>[];
    for (var i = 0; i < raw.length; i += _group) {
      final end = (i + _group) > raw.length ? raw.length : (i + _group);
      chunks.add(raw.substring(i, end));
    }
    return chunks.join('-');
  }
}
