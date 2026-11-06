import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/voice/voice_service.dart';
import 'package:frontend/features/assistant/assistant_screen.dart';

void main() {
  test('a product is read with its known price, or says it has none', () {
    expect(
      productSpeech('Riz 1 kg', '1 250 XAF'),
      'Riz 1 kg. Meilleur prix connu : 1 250 XAF.',
    );
    expect(
      productSpeech('Riz 1 kg', null),
      'Riz 1 kg. Aucun prix connu pour le moment.',
    );
  });

  test('an assistant reply keeps its intent for the escalation banner', () {
    final reply = AssistantMessage.fromJson({
      'role': 'assistant',
      'content': 'Demande TCK-1 transmise à un conseiller.',
      'intent': 'support',
    });
    expect(reply.fromUser, isFalse);
    expect(reply.intent, 'support');
  });
}
