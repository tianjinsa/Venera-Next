import 'package:flutter/material.dart';
import 'package:prism_ui/card.dart' as prism show Card;
import 'package:prism_ui/common_button.dart'
    as prism
    show ButtonStyle, TextButton;
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:prism_ui/popup.dart' as prism show PopupMenuItem;
import 'package:prism_ui/search_field.dart' as prism show SearchField;
import 'package:venera_next/components/mobile_ui.dart';

import 'agent_models.dart';

class AgentHistoryPanel extends StatefulWidget {
  final List<AgentConversation> conversations;
  final String currentId;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onNew;
  final VoidCallback? close;
  final bool mobile;
  final ValueChanged<AgentConversation> onSelect;
  final ValueChanged<AgentConversation> onRename;
  final Future<bool> Function(List<AgentConversation>) onDelete;
  const AgentHistoryPanel({
    super.key,
    required this.conversations,
    required this.currentId,
    required this.search,
    required this.onSearch,
    required this.onNew,
    this.close,
    this.mobile = false,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<AgentHistoryPanel> createState() => _AgentHistoryPanelState();
}

class _AgentHistoryPanelState extends State<AgentHistoryPanel> {
  bool _selecting = false;
  bool _deleting = false;
  final _selected = <String>{};

  @override
  void didUpdateWidget(covariant AgentHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visible = widget.conversations.map((c) => c.id).toSet();
    _selected.removeWhere((id) => !visible.contains(id));
  }

  void _toggle(AgentConversation conversation) {
    if (_deleting) return;
    setState(() {
      _selecting = true;
      if (!_selected.add(conversation.id)) _selected.remove(conversation.id);
    });
  }

  Future<void> _delete() async {
    final selected = widget.conversations
        .where((c) => _selected.contains(c.id))
        .toList();
    if (selected.isEmpty || _deleting) return;
    setState(() => _deleting = true);
    try {
      if (await widget.onDelete(selected) && mounted) {
        setState(() {
          _selected.clear();
          _selecting = false;
        });
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _toggleMode() => setState(() {
    _selecting = !_selecting;
    _selected.clear();
  });

  void _toggleAll(bool all) => setState(() {
    _selected.clear();
    if (!all) _selected.addAll(widget.conversations.map((c) => c.id));
  });

  Widget _mobileContent(BuildContext context, bool all, int selectedBytes) {
    final theme = Theme.of(context);
    final canSelectAll = !_deleting && widget.conversations.isNotEmpty;
    final canDelete = !_deleting && _selected.isNotEmpty;
    return CustomScrollView(
      key: const ValueKey('agent-history-mobile-scroll'),
      primary: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selecting ? '已选 ${_selected.length} 段' : '历史对话',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (_selecting)
                      MobileToolbarButton(
                        key: const ValueKey('agent-history-manage'),
                        label: '退出多选',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _deleting ? null : _toggleMode,
                      ),
                    if (!_selecting)
                      MobileToolbarButton(
                        label: widget.close == null ? '新对话' : '关闭',
                        icon: Icon(
                          widget.close == null ? Icons.add : Icons.close,
                        ),
                        onPressed: widget.close ?? widget.onNew,
                      ),
                    if (!_selecting)
                      MobileMenuButton(
                        key: const ValueKey('agent-history-more'),
                        items: [
                          prism.PopupMenuItem(
                            label: '管理对话',
                            onPressed: canSelectAll ? _toggleMode : null,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ExcludeFocus(
                  excluding: _deleting,
                  child: IgnorePointer(
                    ignoring: _deleting,
                    child: prism.SearchField(
                      controller: widget.search,
                      onChanged: widget.onSearch,
                      hintText: '搜索对话',
                      fill: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
                ),
                if (_selecting) ...[
                  const SizedBox(height: 8),
                  Text(
                    '所选内容约 ${agentFormatBytes(selectedBytes)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      // Remount only the button on state changes: the
                      // pinned Prism button notifies its press surface during
                      // didUpdateWidget when enabled changes.
                      KeyedSubtree(
                        key: const ValueKey('agent-history-select-all'),
                        child: prism.TextButton(
                          key: ValueKey(canSelectAll),
                          onPressed: canSelectAll
                              ? () => _toggleAll(all)
                              : null,
                          child: Text(all ? '取消全选' : '全选结果'),
                        ),
                      ),
                      KeyedSubtree(
                        key: const ValueKey('agent-history-delete-selected'),
                        child: prism.TextButton.icon(
                          key: ValueKey(canDelete),
                          onPressed: canDelete ? _delete : null,
                          style: prism.ButtonStyle.from(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(_deleting ? '删除中' : '删除所选'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.conversations.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('没有匹配的对话')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: widget.conversations.length,
              itemBuilder: (context, index) =>
                  _mobileRow(widget.conversations[index]),
            ),
          ),
      ],
    );
  }

  Widget _mobileRow(AgentConversation conversation) {
    final date = DateTime.fromMillisecondsSinceEpoch(conversation.updatedAt);
    final selected = _selecting
        ? _selected.contains(conversation.id)
        : conversation.id == widget.currentId;
    final VoidCallback? onLongPress = _deleting
        ? null
        : () => _toggle(conversation);
    return Padding(
      key: ValueKey('history-${conversation.id}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        selected: selected,
        onLongPress: onLongPress,
        child: GestureDetector(
          excludeFromSemantics: true,
          onLongPress: onLongPress,
          child: prism.Card(
            padding: EdgeInsets.zero,
            isSelected: selected,
            fillsSelection: true,
            onPressed: _deleting
                ? null
                : () => _selecting
                      ? _toggle(conversation)
                      : widget.onSelect(conversation),
            child: prism.ListRow(
              minVerticalPadding: 8,
              leading: !_selecting
                  ? null
                  : Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
              title: Text(conversation.title),
              subtitle: Text(
                '${date.month}/${date.day} · ${conversation.messageCount} 条消息'
                '\n约 ${agentFormatBytes(conversation.storageBytes)}',
                key: ValueKey('history-size-${conversation.id}'),
              ),
              trailing: _selecting
                  ? null
                  : MobileMenuButton(
                      label: '对话选项',
                      items: [
                        prism.PopupMenuItem(
                          label: '重命名',
                          onPressed: () => widget.onRename(conversation),
                        ),
                        prism.PopupMenuItem(
                          label: '选择对话',
                          onPressed: () => _toggle(conversation),
                        ),
                        prism.PopupMenuItem(
                          label: '删除',
                          onPressed: () => widget.onDelete([conversation]),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all =
        widget.conversations.isNotEmpty &&
        _selected.length == widget.conversations.length;
    final selectedBytes = widget.conversations
        .where((c) => _selected.contains(c.id))
        .fold<int>(0, (total, c) => total + c.storageBytes);
    if (widget.mobile) return _mobileContent(context, all, selectedBytes);
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selecting ? '已选 ${_selected.length} 段' : '历史对话',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              IconButton(
                key: const ValueKey('agent-history-manage'),
                tooltip: _selecting ? '退出多选' : '管理对话',
                onPressed: _deleting ? null : _toggleMode,
                icon: Icon(
                  _selecting ? Icons.close : Icons.checklist_rounded,
                  size: 20,
                ),
              ),
              if (!_selecting)
                IconButton(
                  tooltip: widget.close == null ? '新对话' : '关闭',
                  onPressed: widget.close ?? widget.onNew,
                  icon: Icon(
                    widget.close == null ? Icons.add : Icons.close,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: widget.search,
            onChanged: widget.onSearch,
            enabled: !_deleting,
            decoration: InputDecoration(
              hintText: '搜索对话',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_selecting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Text(
                  '所选内容约 ${agentFormatBytes(selectedBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      key: const ValueKey('agent-history-select-all'),
                      onPressed: _deleting || widget.conversations.isEmpty
                          ? null
                          : () => _toggleAll(all),
                      child: Text(all ? '取消全选' : '全选结果'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('agent-history-delete-selected'),
                      onPressed: _selected.isEmpty || _deleting
                          ? null
                          : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(_deleting ? '删除中' : '删除所选'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.conversations.isEmpty
              ? const Center(child: Text('没有匹配的对话'))
              : ListView.builder(
                  itemCount: widget.conversations.length,
                  itemBuilder: (_, index) {
                    final conversation = widget.conversations[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      conversation.updatedAt,
                    );
                    final selected = _selecting
                        ? _selected.contains(conversation.id)
                        : conversation.id == widget.currentId;
                    // Marked like the selected folder in the favorites page.
                    return Ink(
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer.withValues(alpha: .36)
                            : null,
                        border: Border(
                          left: BorderSide(
                            color: selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: ListTile(
                        key: ValueKey('history-${conversation.id}'),
                        contentPadding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
                        horizontalTitleGap: 6,
                        minLeadingWidth: 24,
                        leading: _selecting
                            ? Checkbox(
                                value: _selected.contains(conversation.id),
                                visualDensity: VisualDensity.compact,
                                onChanged: _deleting
                                    ? null
                                    : (_) => _toggle(conversation),
                              )
                            : null,
                        title: Text(
                          conversation.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${date.month}/${date.day} · ${conversation.messageCount} 条消息',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '约 ${agentFormatBytes(conversation.storageBytes)}',
                              key: ValueKey('history-size-${conversation.id}'),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        onTap: _deleting
                            ? null
                            : () => _selecting
                                  ? _toggle(conversation)
                                  : widget.onSelect(conversation),
                        onLongPress: _deleting
                            ? null
                            : () => _toggle(conversation),
                        trailing: _selecting
                            ? null
                            : SizedBox(
                                width: 32,
                                child: PopupMenuButton<String>(
                                  tooltip: '对话选项',
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_horiz, size: 18),
                                  onSelected: (action) {
                                    if (action == 'delete') {
                                      widget.onDelete([conversation]);
                                    } else if (action == 'select') {
                                      _toggle(conversation);
                                    } else {
                                      widget.onRename(conversation);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('重命名'),
                                    ),
                                    PopupMenuItem(
                                      value: 'select',
                                      child: Text('选择对话'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除'),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
