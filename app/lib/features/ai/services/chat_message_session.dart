import '../models/ai_chat_message.dart';

/// Message identity and history reconciliation shared by single and group chat.
///
/// UI pages remain responsible for rendering and network requests; this class
/// owns the deterministic, provider-free rules that must stay identical.
class ChatMessageSession {
  int _localSequence = 0;

  String nextLocalId() =>
      'local-${DateTime.now().microsecondsSinceEpoch}-${_localSequence++}';

  List<AiMessage> deduplicateAndSort(Iterable<AiMessage> messages) {
    final byId = <String, AiMessage>{
      for (final message in messages) message.id: message,
    };
    return byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<AiMessage> mergeServerHistory({
    required Iterable<AiMessage> current,
    required Iterable<AiMessage> server,
    required bool Function(AiMessage server, AiMessage optimistic) sameOutgoing,
  }) {
    final authoritative = server.toList();
    final optimistic = current.where(
      (message) =>
          message.id.startsWith('local-') &&
          !authoritative.any(
            (serverMessage) => sameOutgoing(serverMessage, message),
          ),
    );
    return deduplicateAndSort([...authoritative, ...optimistic]);
  }
}
