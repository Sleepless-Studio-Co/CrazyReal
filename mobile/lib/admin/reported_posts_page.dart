import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';
import '../widgets/post_card.dart';

class ReportedPostsPage extends StatefulWidget {
  const ReportedPostsPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<ReportedPostsPage> createState() => _ReportedPostsPageState();
}

class _ReportedPostsPageState extends State<ReportedPostsPage> {
  final AdminService _service = AdminService();
  List<AdminReportedPost> _posts = [];
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
      final posts = await _service.getReportedPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
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

  Future<void> _restore(AdminReportedPost item) async {
    await _run(item.post.id, () => _service.restorePost(item.post.id));
  }

  Future<void> _delete(AdminReportedPost item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminDeletePostTitle),
        content: Text(l10n.adminDeletePostBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(item.post.id, () => _service.deleteReportedPost(item.post.id));
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
      appBar: AppBar(title: Text(l10n.adminReportedPostsTitle)),
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
            Text(l10n.adminReportedPostsLoadError),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(l10n.feedRetry)),
          ],
        ),
      );
    }
    if (_posts.isEmpty) return Center(child: Text(l10n.adminNoReportedPosts));

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, index) {
          final item = _posts[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _ModerationStatusChip(status: item.status),
                        const SizedBox(width: 8),
                        Text(l10n.adminReportCount(item.reportCount)),
                      ],
                    ),
                  ),
                  if (_busyId == item.post.id)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else ...[
                    IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: l10n.adminRestorePost,
                        onPressed: () => _restore(item)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.delete,
                        onPressed: () => _delete(item)),
                  ],
                ],
              ),
              PostCard(post: item.post, unknownUserLabel: l10n.unknownUser),
            ],
          );
        },
      ),
    );
  }
}

class _ModerationStatusChip extends StatelessWidget {
  const _ModerationStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'GHOSTED' => ('Fantôme', Colors.orange.shade800),
      'APPROVED' => ('Approuvé', Colors.green.shade700),
      'REMOVED' => ('Supprimé', Colors.red.shade700),
      _ => ('À vérifier', Colors.blueGrey.shade700),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      visualDensity: VisualDensity.compact,
    );
  }
}
