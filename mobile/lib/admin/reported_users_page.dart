import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';

class ReportedUsersPage extends StatefulWidget {
  const ReportedUsersPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<ReportedUsersPage> createState() => _ReportedUsersPageState();
}

class _ReportedUsersPageState extends State<ReportedUsersPage> {
  final AdminService _service = AdminService();
  List<AdminReportedUser> _users = [];
  bool _loading = true;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final users = await _service.getReportedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : error.toString();
      });
    }
  }

  Future<void> _ban(AdminReportedUser user) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) => _BanReasonDialog(l10n: l10n),
    );
    if (reason == null || !mounted) return;
    await _run(user.id, () => _service.banUser(user.id, reason: reason));
  }

  Future<void> _toggleBan(AdminReportedUser user) async {
    if (user.isBanned) {
      await _run(user.id, () => _service.unbanUser(user.id));
    } else {
      await _ban(user);
    }
  }

  Future<void> _run(int id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
      await _load(showLoading: false);
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  error is ApiException ? error.message : error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminReportedUsersTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminReportedUsersLoadError),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(l10n.feedRetry)),
          ],
        ),
      );
    }
    if (_users.isEmpty) return Center(child: Text(l10n.adminNoReportedUsers));

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final user = _users[index];
          return ListTile(
            tileColor:
                user.isBanned ? Colors.red.withValues(alpha: 0.08) : null,
            title: Text(user.username),
            subtitle: Text(
              '${l10n.adminTotalReports(user.reportCount)}${user.banReason == null ? '' : '\n${user.banReason}'}',
            ),
            trailing: _busyId == user.id
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: Icon(user.isBanned ? Icons.lock_open : Icons.block),
                    tooltip: user.isBanned
                        ? l10n.adminUnbanAction
                        : l10n.adminBanAction,
                    onPressed: () => _toggleBan(user),
                  ),
          );
        },
      ),
    );
  }
}

class _BanReasonDialog extends StatefulWidget {
  const _BanReasonDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_BanReasonDialog> createState() => _BanReasonDialogState();
}

class _BanReasonDialogState extends State<_BanReasonDialog> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.adminBanUserTitle),
      content: TextField(
        controller: _reasonController,
        maxLines: 3,
        decoration: InputDecoration(labelText: l10n.adminBanReasonLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _reasonController.text.trim(),
          ),
          child: Text(l10n.adminBanAction),
        ),
      ],
    );
  }
}
