import '../../../core/database/app_database.dart';
import '../models/ai_chat_message.dart';

/// Shared Drift mapping/persistence for single and group chat messages.
class ChatCacheStore {
  const ChatCacheStore(this.database);

  final AppDatabase database;

  Future<List<AiMessage>> read(String conversationId) async => [
        for (final row in await database.getChatMessages(conversationId))
          messageFromCacheRow(row),
      ];

  Future<void> upsert(
    String conversationId,
    Iterable<AiMessage> messages,
  ) async {
    final rows = [
      for (final message in messages)
        if (message.id.isNotEmpty) cacheRowFromMessage(conversationId, message),
    ];
    if (rows.isNotEmpty) await database.upsertChatMessages(rows);
  }

  Future<void> replace(
    String conversationId,
    Iterable<AiMessage> messages,
  ) async {
    await database.deleteChatMessages(conversationId);
    await upsert(conversationId, messages);
  }
}

AiMessage messageFromCacheRow(ChatMessageRow row) => AiMessage(
      id: row.id,
      role: row.role,
      kind: row.kind,
      content: row.content ?? '',
      mediaAssetId: row.mediaAssetId,
      stickerId: row.stickerId,
      caption: row.caption,
      fileName: row.fileName,
      fileSize: row.fileSize,
      audioDuration: row.audioDuration,
      quote: row.quoteContent,
      quoteMessageId: row.quoteMessageId,
      quoteRole: row.quoteRole,
      senderCharacterId: row.senderCharacterId,
      amount: row.amount,
      claimed: row.claimed,
      claimers: AiMessage.claimersFromDb(row.claimers),
      transferAccepted: row.transferAccepted,
      createdAt: row.createdAt,
    );

ChatMessageRow cacheRowFromMessage(
  String conversationId,
  AiMessage message,
) =>
    ChatMessageRow(
      conversationId: conversationId,
      id: message.id,
      role: message.role,
      kind: message.kind,
      content: message.content,
      mediaAssetId: message.mediaAssetId,
      stickerId: message.stickerId,
      caption: message.caption,
      fileName: message.fileName,
      fileSize: message.fileSize,
      audioDuration: message.audioDuration,
      quoteMessageId: message.quoteMessageId,
      quoteRole: message.quoteRole,
      quoteContent: message.quote,
      senderCharacterId: message.senderCharacterId,
      amount: message.amount,
      claimed: message.claimed,
      claimers: AiMessage.claimersToDb(message.claimers),
      transferAccepted: message.transferAccepted,
      createdAt: message.createdAt,
    );
