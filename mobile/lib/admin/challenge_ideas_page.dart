import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';

const _ideaInk = Color(0xFF3B2A21);
const _ideaMuted = Color(0xFF6A4A3B);
const _ideaCard = Color(0xFFFFF7E6);

class ChallengeIdeasPage extends StatefulWidget {
  const ChallengeIdeasPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<ChallengeIdeasPage> createState() => _ChallengeIdeasPageState();
}

class _ChallengeIdeasPageState extends State<ChallengeIdeasPage> {
  final AdminService _service = AdminService();
  List<AdminChallengeIdea> _ideas = [];
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
      final ideas = await _service.getChallengeIdeas();
      if (!mounted) return;
      setState(() {
        _ideas = ideas;
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

  Future<void> _setStatus(
      AdminChallengeIdea idea, ChallengeIdeaStatus status) async {
    setState(() => _busyId = idea.id);
    try {
      final updated = await _service.updateChallengeIdeaStatus(idea.id, status);
      if (!mounted) return;
      setState(() {
        final index = _ideas.indexWhere((item) => item.id == idea.id);
        if (index != -1) _ideas[index] = updated;
      });
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(error is ApiException ? error.message : error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.adminChallengeIdeasTitle,
          style: GoogleFonts.dmSerifDisplay(color: _ideaInk, fontSize: 22),
        ),
        backgroundColor: const Color(0xFFF7EBD1),
        elevation: 0,
      ),
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
            Text(l10n.adminChallengeIdeasLoadError),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _ideaMuted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: Text(l10n.feedRetry)),
          ],
        ),
      );
    }
    if (_ideas.isEmpty) {
      return Center(child: Text(l10n.adminNoChallengeIdeas));
    }
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _ideas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final idea = _ideas[index];
          return _IdeaCard(
            idea: idea,
            busy: _busyId == idea.id,
            onStatusChanged: (status) => _setStatus(idea, status),
          );
        },
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.idea,
    required this.busy,
    required this.onStatusChanged,
  });

  final AdminChallengeIdea idea;
  final bool busy;
  final ValueChanged<ChallengeIdeaStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = DateFormat('dd/MM/yyyy HH:mm').format(idea.createdAt);
    final status = switch (idea.status) {
      ChallengeIdeaStatus.pending => (l10n.adminIdeaPending, Colors.orange),
      ChallengeIdeaStatus.approved => (l10n.adminIdeaApproved, Colors.green),
      ChallengeIdeaStatus.rejected => (l10n.adminIdeaRejected, Colors.red),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ideaCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DFC2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  idea.username,
                  style: GoogleFonts.karla(
                    color: _ideaInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _IdeaStatusChip(label: status.$1, color: status.$2),
            ],
          ),
          const SizedBox(height: 10),
          Text(idea.content,
              style: GoogleFonts.karla(color: _ideaInk, fontSize: 15)),
          const SizedBox(height: 8),
          Text(date, style: GoogleFonts.karla(color: _ideaMuted, fontSize: 12)),
          const SizedBox(height: 12),
          if (busy)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                _IdeaAction(
                  label: l10n.adminIdeaApprove,
                  icon: Icons.check,
                  color: Colors.green,
                  selected: idea.status == ChallengeIdeaStatus.approved,
                  onPressed: () =>
                      onStatusChanged(ChallengeIdeaStatus.approved),
                ),
                _IdeaAction(
                  label: l10n.adminIdeaReject,
                  icon: Icons.close,
                  color: Colors.red,
                  selected: idea.status == ChallengeIdeaStatus.rejected,
                  onPressed: () =>
                      onStatusChanged(ChallengeIdeaStatus.rejected),
                ),
                _IdeaAction(
                  label: l10n.adminIdeaPending,
                  icon: Icons.hourglass_empty,
                  color: _ideaMuted,
                  selected: idea.status == ChallengeIdeaStatus.pending,
                  onPressed: () => onStatusChanged(ChallengeIdeaStatus.pending),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IdeaAction extends StatelessWidget {
  const _IdeaAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.selected,
      required this.onPressed});

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: selected ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: color),
    );
  }
}

class _IdeaStatusChip extends StatelessWidget {
  const _IdeaStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      labelStyle:
          TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
