import 'package:sip_ua/src/config.dart' as config;
import 'package:sip_ua/src/rtc_session.dart';
import 'package:sip_ua/src/transports/websocket_interface.dart';
import 'package:sip_ua/src/ua.dart' show UA;
import 'package:test/test.dart';

/// URSA-10410: an ICE restart re-INVITE sent while the network was down must
/// never end the call when it fails. ICE can recover on its own before the
/// SIP transport reports the failure; the session used to read that as "not
/// an ICE restart any more" and terminated the call with 500.
void main() {
  late RTCSession session;

  setUp(() {
    final config.Settings settings = config.Settings()
      ..sockets = <WebSocketInterface>[
        WebSocketInterface('ws://127.0.0.1:5070/sip', messageDelay: 0),
      ]
      ..authorization_user = '100'
      ..password = '100'
      ..uri = 'sip:100@127.0.0.1';

    session = RTCSession(UA(settings))..debugSetStatus(C.STATUS_CONFIRMED);
  });

  group('a failed ICE restart re-INVITE', () {
    test('a transport error keeps the call', () {
      session.onTransportError(true, true);

      expect(session.isEnded(), isFalse);
    });

    test('a request timeout keeps the call', () {
      session.onRequestTimeout(isRenegotiating: true, isIceRestart: true);

      expect(session.isEnded(), isFalse);
    });

    test('a dialog error keeps the call', () {
      session.onDialogError(true, true);

      expect(session.isEnded(), isFalse);
    });

    test('tries the ICE restart again while the media is not up', () {
      session.onTransportError(true, true);

      expect(session.debugIsIceRestartRetrying, isTrue);
    });
  });
}
