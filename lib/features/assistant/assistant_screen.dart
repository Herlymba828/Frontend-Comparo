import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_service.dart';
import '../../core/widgets/async_views.dart';

class AssistantMessage {
  const AssistantMessage({
    required this.fromUser,
    required this.content,
    this.intent = '',
  });

  final bool fromUser;
  final String content;
  final String intent;

  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
        fromUser: json.string('role') == 'user',
        content: json.string('content'),
        intent: json.string('intent'),
      );
}

/// The price assistant (PJ-023): answers from the platform's data only, and
/// hands over to a person on "support".
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _messages = <AssistantMessage>[
    const AssistantMessage(
      fromUser: false,
      content:
          'Bonjour ! Demandez un prix (« prix riz »), une comparaison '
          '(« comparer huile »), vos commandes (« commandes ») ou un '
          'conseiller (« support … »).',
    ),
  ];
  int? _conversationId;
  bool _sending = false;
  bool _escalated = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? spoken]) async {
    final text = (spoken ?? _input.text).trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _messages.add(AssistantMessage(fromUser: true, content: text));
      _input.clear();
    });
    try {
      final api = ref.read(jsonApiProvider);
      final id =
          _conversationId ??
          await api.post<int>(
            'api/assistant/conversations/',
            (json) => json.requireInt('id'),
            data: const {},
          );
      _conversationId = id;
      final reply = await api.post(
        'api/assistant/conversations/$id/send/',
        AssistantMessage.fromJson,
        data: {'content': text},
      );
      if (mounted) {
        setState(() {
          _messages.add(reply);
          _escalated = _escalated || reply.intent == 'support';
        });
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _dictate() async {
    final heard = await ref.read(voiceServiceProvider).listen();
    if (!mounted) {
      return;
    }
    if (heard == null) {
      showInfo(context, 'Je n’ai rien entendu. Vérifiez le micro.');
      return;
    }
    // Shown before it is sent: the user checks the transcription (PJ-026).
    setState(() => _input.text = heard);
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.read(voiceServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant prix')),
      body: SignedInGate(
        signInMessage: 'Connectez-vous pour parler à l’assistant.',
        builder: (user) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.space8),
                      padding: const EdgeInsets.all(AppSpacing.space12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: message.fromUser
                            ? AppColors.accent
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(color: AppColors.ink),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.content),
                          if (!message.fromUser)
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'Écouter',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => voice.speak(message.content),
                                icon: const Icon(Icons.volume_up_outlined),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_escalated)
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Un conseiller a votre demande'),
                subtitle: const Text('Suivez-la dans Aide et réclamations.'),
                onTap: () => context.push('/support'),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Dicter',
                      onPressed: _sending ? null : _dictate,
                      icon: const Icon(Icons.mic_none),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Votre question',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Envoyer',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
