import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/errors/result.dart';
import '../../../../data/repositories/lobby_repository.dart';

/// Dialog for creating a new lobby.
class CreateLobbyDialog extends StatefulWidget {
  const CreateLobbyDialog({super.key});

  @override
  State<CreateLobbyDialog> createState() => _CreateLobbyDialogState();
}

class _CreateLobbyDialogState extends State<CreateLobbyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: '');
  final _feeCtrl = TextEditingController(text: '1.00');
  final _lobbyRepo = LobbyRepository();

  String _mode = '5v5';
  String _region = 'EU';
  bool _isPrivate = false;
  bool _isLoading = false;
  String? _error;

  int get _maxPlayers =>
      MatchMode.values.firstWhere((m) => m.label == _mode).totalPlayers;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = SupabaseConfig.auth.currentUser!.id;
    final fee = double.tryParse(_feeCtrl.text) ?? 0;

    final result = await _lobbyRepo.createLobby({
      'created_by': userId,
      'name': _nameCtrl.text.trim(),
      'mode': _mode,
      'entry_fee': fee,
      'max_players': _maxPlayers,
      'region': _region,
      'is_private': _isPrivate,
    });

    if (!mounted) return;

    result.when(
      success: (lobby) {
        // Auto-join the creator
        _lobbyRepo.joinLobby(lobby.id, userId, team: 'team_a');
        Navigator.of(context).pop(lobby);
      },
      failure: (msg, _) => setState(() {
        _isLoading = false;
        _error = msg;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text('Create Lobby', style: AppTextStyles.h3),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Error
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.danger)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Lobby Name
                _Label('LOBBY NAME'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: AppTextStyles.bodyLarge,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Pro 5v5 EU'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (v.trim().length < 2) return 'Min 2 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Mode + Region row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('MODE'),
                          const SizedBox(height: 6),
                          _SegmentedSelector(
                            options: const ['1v1', '2v2', '5v5'],
                            selected: _mode,
                            onChanged: (v) => setState(() => _mode = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('REGION'),
                          const SizedBox(height: 6),
                          _SegmentedSelector(
                            options: Region.values.map((r) => r.code).toList(),
                            selected: _region,
                            onChanged: (v) => setState(() => _region = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Entry Fee + Private toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('ENTRY FEE (€)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _feeCtrl,
                            style: AppTextStyles.mono,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              prefixText: '€ ',
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final fee = double.tryParse(v);
                              if (fee == null) return 'Invalid';
                              if (fee < 0) return 'Min €0';
                              if (fee > AppConstants.maxEntryFee) {
                                return 'Max €${AppConstants.maxEntryFee}';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('VISIBILITY'),
                          const SizedBox(height: 6),
                          _SegmentedSelector(
                            options: const ['Public', 'Private'],
                            selected: _isPrivate ? 'Private' : 'Public',
                            onChanged: (v) =>
                                setState(() => _isPrivate = v == 'Private'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceActive,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_mode · $_region · $_maxPlayers players · ${_isPrivate ? "Private" : "Public"}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _create,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Lobby'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.textTertiary, letterSpacing: 1.0));
  }
}

class _SegmentedSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SegmentedSelector(
      {required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceActive,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: options.map((o) {
          final isActive = o == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: isActive
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(
                  o,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
