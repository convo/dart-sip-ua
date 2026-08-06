class IceServerSummary {
  IceServerSummary({
    required this.count,
    required this.stunConfigured,
    required this.turnConfigured,
  });

  factory IceServerSummary.fromPcConfig(Map<String, dynamic>? pcConfig) {
    dynamic configuredServers = pcConfig?['iceServers'];
    List<dynamic> servers = configuredServers is Iterable
        ? configuredServers.toList()
        : configuredServers == null
            ? <dynamic>[]
            : <dynamic>[configuredServers];
    bool stunConfigured = false;
    bool turnConfigured = false;

    for (dynamic server in servers) {
      dynamic configuredUrls = server is Map
          ? server['urls'] ?? server['url']
          : server;
      List<dynamic> urls = configuredUrls is Iterable && configuredUrls is! String
          ? configuredUrls.toList()
          : configuredUrls == null
              ? <dynamic>[]
              : <dynamic>[configuredUrls];
      for (dynamic value in urls) {
        String url = value.toString().toLowerCase();
        stunConfigured =
            stunConfigured || url.startsWith('stun:') || url.startsWith('stuns:');
        turnConfigured =
            turnConfigured || url.startsWith('turn:') || url.startsWith('turns:');
      }
    }

    return IceServerSummary(
      count: servers.length,
      stunConfigured: stunConfigured,
      turnConfigured: turnConfigured,
    );
  }

  final int count;
  final bool stunConfigured;
  final bool turnConfigured;

  String get logFields =>
      'iceServerCount=$count stunConfigured=$stunConfigured '
      'turnConfigured=$turnConfigured';
}

class IceSdpSummary {
  IceSdpSummary({
    required this.total,
    required this.host,
    required this.srflx,
    required this.relay,
    required this.prflx,
    required this.unknown,
    required this.udp,
    required this.tcp,
    required this.unknownProtocol,
    required this.candidatesByMid,
  });

  factory IceSdpSummary.fromSdp(String? sdp) {
    int total = 0;
    int host = 0;
    int srflx = 0;
    int relay = 0;
    int prflx = 0;
    int unknown = 0;
    int udp = 0;
    int tcp = 0;
    int unknownProtocol = 0;
    int currentMediaSection = -1;
    int sessionLevelCandidates = 0;
    List<int> candidateCountsBySection = <int>[];
    List<String?> midsBySection = <String?>[];
    Map<String, int> candidatesByMid = <String, int>{};

    for (String rawLine in (sdp ?? '').split(RegExp(r'\r?\n'))) {
      String line = rawLine.trim();
      if (line.startsWith('m=')) {
        currentMediaSection += 1;
        candidateCountsBySection.add(0);
        midsBySection.add(null);
        continue;
      }
      if (line.startsWith('a=mid:')) {
        if (currentMediaSection >= 0) {
          midsBySection[currentMediaSection] =
              line.substring('a=mid:'.length);
        }
        continue;
      }
      if (!line.startsWith('a=candidate:')) {
        continue;
      }

      total += 1;
      if (currentMediaSection >= 0) {
        candidateCountsBySection[currentMediaSection] += 1;
      } else {
        sessionLevelCandidates += 1;
      }
      switch (candidateType(line)) {
        case 'host':
          host += 1;
          break;
        case 'srflx':
          srflx += 1;
          break;
        case 'relay':
          relay += 1;
          break;
        case 'prflx':
          prflx += 1;
          break;
        default:
          unknown += 1;
      }
      switch (candidateProtocol(line)) {
        case 'udp':
          udp += 1;
          break;
        case 'tcp':
          tcp += 1;
          break;
        default:
          unknownProtocol += 1;
      }
    }

    if (sessionLevelCandidates > 0) {
      candidatesByMid['none'] = sessionLevelCandidates;
    }
    for (int index = 0; index < candidateCountsBySection.length; index += 1) {
      int count = candidateCountsBySection[index];
      if (count == 0) {
        continue;
      }
      String? mid = midsBySection[index];
      String key = mid == null || mid.isEmpty ? 'm$index' : mid;
      candidatesByMid[key] = (candidatesByMid[key] ?? 0) + count;
    }

    return IceSdpSummary(
      total: total,
      host: host,
      srflx: srflx,
      relay: relay,
      prflx: prflx,
      unknown: unknown,
      udp: udp,
      tcp: tcp,
      unknownProtocol: unknownProtocol,
      candidatesByMid: candidatesByMid,
    );
  }

  static final RegExp _candidateTypePattern =
      RegExp(r'(?:^|\s)typ\s+(host|srflx|relay|prflx)(?:\s|$)');
  static final RegExp _candidateProtocolPattern =
      RegExp(r'^(?:a=)?candidate:\S+\s+\S+\s+(udp|tcp)(?:\s|$)',
          caseSensitive: false);

  static String candidateType(String? candidate) {
    RegExpMatch? match =
        _candidateTypePattern.firstMatch(candidate ?? '');
    return match?.group(1) ?? 'unknown';
  }

  static String candidateProtocol(String? candidate) {
    RegExpMatch? match =
        _candidateProtocolPattern.firstMatch(candidate ?? '');
    return match?.group(1)?.toLowerCase() ?? 'unknown';
  }

  final int total;
  final int host;
  final int srflx;
  final int relay;
  final int prflx;
  final int unknown;
  final int udp;
  final int tcp;
  final int unknownProtocol;
  final Map<String, int> candidatesByMid;

  String get logFields =>
      'total=$total host=$host srflx=$srflx relay=$relay '
      'prflx=$prflx unknown=$unknown udp=$udp tcp=$tcp '
      'unknownProtocol=$unknownProtocol mids=$candidatesByMid';
}
