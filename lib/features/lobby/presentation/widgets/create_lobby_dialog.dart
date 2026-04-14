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
  final _feeCtrl = TextEditingController(text: '0');
  final _lobbyRepo = LobbyRepository();

  int _userBcoins = 0;

  String _mode = '5v5';
  String _region = 'EU';
  bool _isPrivate = false;
  bool _isLoading = false;
  String? _error;

  static const _feePresets = [0, 10, 25, 50, 100, 250, 500];

  int get _maxPlayers =>
      MatchMode.values.firstWhere((m) => m.label == _mode).totalPlayers;

  int get _potTotal {
    final fee = int.tryParse(_feeCtrl.text) ?? 0;
    return fee * _maxPlayers;
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final userId = SupabaseConfig.auth.currentUser!.id;
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('bcoins')
          .eq('id', userId)
          .single();
      if (mounted) setState(() => _userBcoins = profile['bcoins'] as int? ?? 0);
    } catch (_) {}
  }

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
    final fee = int.tryParse(_feeCtrl.text) ?? 0;

    // Check user has enough Bcoins
    if (fee > _userBcoins) {
      setState(() {
        _isLoading = false;
        _error =
            'Insufficient Bcoins. You have $_userBcoins, need $fee to enter.';
      });
      return;
    }

    final result = await _lobbyRepo.createLobby(
      name: _nameCtrl.text.trim(),
      mode: _mode,
      region: _region,
      entryFee: fee.toInt(),
      maxPlayers: _maxPlayers,
      isPrivate: _isPrivate,
      // minElo, maxElo default la 0 și 15000
    );

    if (!mounted) return;

    if (result.isFailure) {
      setState(() {
        _isLoading = false;
        _error = result.error;
      });
      return;
    }

    final lobby = result.data!;

    // Auto-join the creator (deducts fee via RPC)
    final joinResult =
        await _lobbyRepo.joinLobby(lobby.id, userId, team: 'team_a');
    if (!mounted) return;

    if (joinResult.isFailure) {
      // Rare: lobby created but creator couldn't join (e.g. race condition)
      setState(() {
        _isLoading = false;
        _error = joinResult.error;
      });
      return;
    }

    Navigator.of(context).pop(lobby);
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

                // Entry Fee (Bcoins) section
                Row(
                  children: [
                    _Label('ENTRY FEE (BCOINS)'),
                    const Spacer(),
                    // User balance chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFE8A33E),
                                Color(0xFFD4891F)
                              ]),
                              borderRadius: BorderRadius.circular(3)),
                          child: const Center(
                              child: Text('B',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900))),
                        ),
                        const SizedBox(width: 5),
                        Text('Balance: $_userBcoins',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Preset chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _feePresets.map((preset) {
                    final isSelected =
                        (int.tryParse(_feeCtrl.text) ?? 0) == preset;
                    final insufficient = preset > _userBcoins;
                    return GestureDetector(
                      onTap: insufficient
                          ? null
                          : () {
                              setState(() => _feeCtrl.text = '$preset');
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.bgSurfaceActive,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent.withValues(alpha: 0.4)
                                : insufficient
                                    ? AppColors.border.withValues(alpha: 0.3)
                                    : AppColors.border,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(preset == 0 ? 'Free' : '$preset',
                              style: AppTextStyles.mono.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.accent
                                      : insufficient
                                          ? AppColors.textTertiary
                                              .withValues(alpha: 0.5)
                                          : AppColors.textSecondary)),
                          if (preset > 0) ...[
                            const SizedBox(width: 3),
                            Text('B',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.accent
                                            .withValues(alpha: 0.6)
                                        : AppColors.textTertiary)),
                          ],
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Custom amount + Visibility
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _feeCtrl,
                        style: AppTextStyles.mono,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Custom amount',
                          prefixIcon: Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.textTertiary),
                          suffixText: 'B',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final fee = int.tryParse(v);
                          if (fee == null) return 'Invalid';
                          if (fee < 0) return 'Min 0';
                          if (fee > AppConstants.maxEntryFeeBcoins) {
                            return 'Max ${AppConstants.maxEntryFeeBcoins}B';
                          }
                          if (fee > _userBcoins) return 'Insufficient';
                          return null;
                        },
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

                const SizedBox(height: 14),

                // Summary with pot
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceActive,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(children: [
                    Text(
                        '$_mode · $_region · $_maxPlayers players · ${_isPrivate ? "Private" : "Public"}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                        textAlign: TextAlign.center),
                    if (_potTotal > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                          height: 1,
                          color: AppColors.border.withValues(alpha: 0.3)),
                      const SizedBox(height: 6),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('TOTAL POT: ',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.8)),
                            Text('$_potTotal',
                                style: AppTextStyles.mono.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            const SizedBox(width: 2),
                            Text('B',
                                style: AppTextStyles.caption.copyWith(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ],
                  ]),
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
