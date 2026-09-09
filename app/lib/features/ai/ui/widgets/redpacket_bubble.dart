import 'package:flutter/material.dart';

import '../../models/ai_chat_message.dart';

/// 微信红包/转账卡片（033+R4，假钱）：kind=redpacket|transfer 时渲染。
///
/// - 红包：微信红底金字卡 +「微信红包」标题 + 金色圆钮金额（两位小数），
///   已被领取后底部文案变「红包已被领取」；
/// - 转账：微信白底卡 + 底部状态栏三态（验收批2）——AI 已收下=绿标「已收钱」、
///   婉拒=灰标「已被婉拒」、待回应=灰标「待收钱」；点开：收下 → 微信收款成功绿勾
///   （¥金额+已存入零钱）、婉拒 → 「对方婉拒了这笔转账」。
///
/// 点开弹层：
/// - 未领取且是 AI 发来的（message.isMe=false）→「开心收下」按钮，回调 onClaim
///   本地标记（假钱无真实支付；AI 领取由后端必回落库）；
/// - 已领取 → 显示「AI 已领取」/ 群拆包人列表（name + 时间）；
/// - 自己发的红包未领取（等 AI）→ 只读提示「等待领取」。
class RedPacketBubble extends StatelessWidget {
  const RedPacketBubble({
    super.key,
    required this.message,
    this.onTap,
    this.onClaim,
  });

  final AiMessage message;

  /// 覆盖默认点开弹层行为（如聊天页已接弹层）。
  final VoidCallback? onTap;

  /// 用户点「开心收下」后本地标记已领取（仅本地；AI 领取由后端落库）。
  final VoidCallback? onClaim;

  bool get _isTransfer => message.kind == 'transfer';

  /// 金额固定两位小数（微信式 ¥6.66；避免 6.6/6.60 显示不一致）。
  String get _amountText {
    final v = message.amount;
    if (v == null) return '';
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => _openDialog(context),
      child: _isTransfer ? _transferCard(context) : _redPacketCard(context),
    );
  }

  // --------------------------------------------------------------------- #
  // 红包（微信红底金字：标题 + 金额圆钮 + 留言 + 领取状态）
  // --------------------------------------------------------------------- #
  Widget _redPacketCard(BuildContext context) {
    const cardW = 216.0;
    final claimed = message.claimed;
    return Container(
      width: cardW,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFA9D3B), Color(0xFFFA5151)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '红包',
                  style: TextStyle(
                    color: Color(0xFFF7E7C4),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _roundButton('¥$_amountText', 54),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.content.trim().isEmpty
                ? '恭喜发财，大吉大利'
                : message.content.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFE1B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            claimed ? '红包已被领取' : '查看红包',
            style: const TextStyle(color: Color(0xFFFFD9C0), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------- #
  // 转账（微信白底卡 + 已收钱状态栏）
  // --------------------------------------------------------------------- #
  Widget _transferCard(BuildContext context) {
    const cardW = 224.0;
    return Container(
      width: cardW,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF07C160),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      size: 22, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '转账',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        message.content.trim().isEmpty
                            ? '转账'
                            : message.content.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF999999), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '¥$_amountText',
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // 状态栏（微信转账「已收钱」绿标下移样式）：
          // 验收批2 三态——true=已收下 / false=已被婉拒 / null=待回应。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F1F0),
            ),
            child: Row(
              children: [
                Icon(
                  message.transferAccepted == true
                      ? Icons.check_circle
                      : (message.transferAccepted == false
                          ? Icons.block
                          : Icons.hourglass_top),
                  size: 14,
                  color: message.transferAccepted == true
                      ? const Color(0xFF07C160)
                      : const Color(0xFF9AA0A6),
                ),
                const SizedBox(width: 4),
                Text(
                  message.transferAccepted == true
                      ? '已收钱'
                      : (message.transferAccepted == false ? '已被婉拒' : '待收钱'),
                  style: TextStyle(
                    color: message.transferAccepted == true
                        ? const Color(0xFF07C160)
                        : const Color(0xFF9AA0A6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(String label, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF7E7C4),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A5A00),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------- #
  // 点开弹层：未领取→收下；已领取→领取人列表
  // --------------------------------------------------------------------- #
  void _openDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(dialogContext),
              const SizedBox(height: 14),
              ..._dialogBody(dialogContext),
              const SizedBox(height: 18),
              _dialogAction(dialogContext),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader(BuildContext context) {
    // 验收批2：已收下的转账 → 微信收款成功绿勾（大勾 + 金额 + 已存入零钱）
    final accepted = _isTransfer && message.transferAccepted == true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          accepted
              ? Icons.check_circle
              : (_isTransfer ? Icons.account_balance_wallet : Icons.redeem),
          size: accepted ? 56 : 44,
          color: accepted
              ? const Color(0xFF07C160)
              : (_isTransfer
                  ? const Color(0xFF07C160)
                  : const Color(0xFFFA9D3B)),
        ),
        const SizedBox(height: 10),
        Text(
          '¥$_amountText',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          accepted ? '已存入余额' : (_isTransfer ? '转账' : '红包'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
        ),
      ],
    );
  }

  /// 弹层中部：已领取 → 领取人列表（群拆包多人；AI=角色名，用户=你）；
  /// 未领取 → 等待领取提示。
  /// 转账（验收批2）单独三态：true=收款成功（绿勾+已存入零钱）/ false=婉拒 / null=等待回应。
  List<Widget> _dialogBody(BuildContext context) {
    if (_isTransfer) {
      if (message.transferAccepted == true) {
        return [
          const Text(
            '已存入零钱，可直接消费',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF07C160)),
          ),
          ..._claimerRows(claimedText: '已收钱'),
        ];
      }
      if (message.transferAccepted == false) {
        return [
          const Text(
            '对方婉拒了这笔转账',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
        ];
      }
      // null：等待 AI 回应
      return [
        Text(
          message.isMe ? '等待对方回应…' : '等待你的回应…',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ];
    }
    if (message.claimed) {
      final rows = _claimerRows(claimedText: '已领取');
      if (rows.isNotEmpty) return rows;
      // 有 claimed 但无列表（如服务端仅标记未带拆包人）→ 兜底文案
      return [
        const Text(
          'AI 已领取',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ];
    }
    // 红包未领取
    return [
      Text(
        message.isMe ? '等待对方领取…' : '拆开看看手气吧',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
      ),
    ];
  }

  /// 领取人列表行（群拆包多人；AI=角色名，用户=你）；无领取人 → 空列表。
  List<Widget> _claimerRows({required String claimedText}) {
    final claimers = message.claimers;
    if (claimers.isEmpty) return const [];
    return [
      for (final c in claimers)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFFF2F2F2),
                child: Icon(Icons.person, size: 18, color: Color(0xFF576B95)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.name,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF111111)),
                ),
              ),
              Text(
                claimedText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF07C160),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _dialogAction(BuildContext context) {
    // 转账（验收批2）：已回应（接受/婉拒）→ 知道了；未回应且是 AI 发来的 → 收下；
    // 自己发的等回应 → 只读等待回应。
    if (_isTransfer) {
      if (message.transferAccepted == null && !message.isMe) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF07C160),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onClaim?.call();
            },
            child: const Text('收下'),
          ),
        );
      }
      if (message.transferAccepted == null) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB0B0B0),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('等待回应'),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF07C160),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      );
    }
    if (message.claimed) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF07C160),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      );
    }
    if (!message.isMe) {
      // AI 发来的未领取 → 可收下
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                _isTransfer ? const Color(0xFF07C160) : const Color(0xFFFA9D3B),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onClaim?.call();
          },
          child: Text(_isTransfer ? '收下' : '开心收下'),
        ),
      );
    }
    // 自己发的红包等 AI 领取：只读
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB0B0B0),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('等待领取'),
      ),
    );
  }
}
