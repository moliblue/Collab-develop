import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/app_localization.dart';
import '../../core/localization/localized_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../ViewModel/auth_view_model.dart';
import '../ViewModel/profile_view_model.dart';
import 'shared/app_widgets.dart';

class ProfileModuleView extends StatelessWidget {
  const ProfileModuleView({
    super.key,
    required this.viewModel,
    required this.authViewModel,
    required this.notify,
  });
  final ProfileViewModel viewModel;
  final AuthViewModel authViewModel;
  final void Function(String, Color) notify;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[viewModel, authViewModel]),
    builder: (BuildContext context, _) => switch (viewModel.stage) {
      ProfileStage.badges => _BadgesView(viewModel: viewModel, notify: notify),
      ProfileStage.passport => _PassportView(
        viewModel: viewModel,
        notify: notify,
      ),
      ProfileStage.login => _LoginView(
        profile: viewModel,
        auth: authViewModel,
        notify: notify,
      ),
      ProfileStage.register => _RegisterView(
        profile: viewModel,
        auth: authViewModel,
        notify: notify,
      ),
      ProfileStage.verifyEmail => _VerifyEmailView(
        profile: viewModel,
        auth: authViewModel,
        notify: notify,
      ),
      ProfileStage.recover => _RecoverView(
        profile: viewModel,
        auth: authViewModel,
        notify: notify,
      ),
      ProfileStage.resetPassword => _ResetPasswordView(
        profile: viewModel,
        auth: authViewModel,
        notify: notify,
      ),
      ProfileStage.dashboard => _Dashboard(
        viewModel: viewModel,
        authViewModel: authViewModel,
        notify: notify,
      ),
    },
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.viewModel,
    required this.authViewModel,
    required this.notify,
  });
  final ProfileViewModel viewModel;
  final AuthViewModel authViewModel;
  final void Function(String, Color) notify;
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey<String>('profile-dashboard'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: <Widget>[
      if (viewModel.error != null) ...<Widget>[
        AppCard(
          color: const Color(0xFFFFEEEE),
          borderColor: AppColors.danger,
          child: Text(
            viewModel.error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 11),
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SectionTitle('Profile', subtitle: 'Your travel profile'),
      const SizedBox(height: 13),
      AppCard(
        radius: AppTokens.cardRadius,
        child: Column(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: <Widget>[
                  Image.asset(
                    'assets/blue_mansion.png',
                    height: 108,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  const Positioned(
                    left: 12,
                    bottom: 10,
                    child: AppChip(
                      label: 'Malaysia heritage explorer',
                      selected: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    InitialsAvatar(
                      viewModel.initials,
                      radius: 40,
                      color: AppColors.softBlue,
                      imageUrl: viewModel.avatarUrl,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        viewModel.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: <Widget>[
                          Icon(
                            Icons.place_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          Expanded(
                            child: Text(
                              ' Malaysia · Heritage explorer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        viewModel.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            const Divider(),
            const SizedBox(height: 11),
            Row(
              children: <Widget>[
                _stat('${viewModel.level}', 'Level'),
                _divider(),
                _stat('${viewModel.trips}', 'Trips'),
                _divider(),
                _stat('${viewModel.xp}', 'XP'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Next level: ${viewModel.nextLevelTitle}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${viewModel.xpToNextLevel} XP to reach Level ${viewModel.nextLevel}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${viewModel.levelProgressPercent}%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: viewModel.levelProgress,
                minHeight: 9,
                backgroundColor: AppColors.elevated,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            _action(
              Icons.edit_rounded,
              context.tr('Edit profile'),
              context.tr('Photo, name and travel bio'),
              AppColors.primary,
              () => _editProfile(context),
            ),
            const Divider(height: 1),
            _action(
              Icons.workspace_premium_rounded,
              context.tr('Achievements & badges'),
              context.tr('Challenges, progress and rewards'),
              AppColors.warning,
              () => viewModel.setStage(ProfileStage.badges),
              key: const Key('open_badges'),
            ),
            const Divider(height: 1),
            _action(
              Icons.auto_stories_rounded,
              context.tr('Passport stamps'),
              viewModel.passportStamps.isEmpty
                  ? context.tr('Your verified destination collection')
                  : '${viewModel.passportStamps.length} collected stamps',
              AppColors.primaryDark,
              () => viewModel.setStage(ProfileStage.passport),
              key: const Key('open_passport'),
            ),
            const Divider(height: 1),
            _action(
              Icons.language_rounded,
              context.tr('Language'),
              viewModel.language,
              AppColors.teal,
              () => _language(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout_rounded),
        label: Text(context.tr('Log out')),
      ),
    ],
  );

  static Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 1,
            fontWeight: FontWeight.w900,
            color: AppColors.muted,
          ),
        ),
      ],
    ),
  );
  static Widget _divider() =>
      Container(height: 32, width: 1, color: AppColors.border);
  static Widget _action(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) => ListTile(
    key: key,
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .1),
      child: Icon(icon, color: color, size: 19),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 9)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
  );

  Future<void> _editProfile(BuildContext context) async {
    final name = TextEditingController(text: viewModel.name);
    final bio = TextEditingController(text: viewModel.bio);
    await showAppSheet<void>(
      context,
      SheetBody(
        children: <Widget>[
          ModalTitle(
            title: 'Edit Profile & Avatar',
            subtitle: authViewModel.currentEmail ?? 'ExploreMY account',
            icon: Icons.edit_rounded,
          ),
          const SizedBox(height: 10),
          Center(
            child: Stack(
              children: <Widget>[
                InitialsAvatar(
                  viewModel.initials,
                  radius: 42,
                  color: AppColors.softBlue,
                  imageUrl: viewModel.avatarUrl,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: viewModel.loading
                          ? null
                          : () => _pickAvatar(context),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Display Name (3–30 chars)',
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: bio,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Personal Bio'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: viewModel.loading
                ? null
                : () async {
                    final error = await viewModel.updateProfile(
                      name.text,
                      bio.text,
                    );
                    if (!context.mounted) return;
                    if (error != null) {
                      notify(error, AppColors.danger);
                      return;
                    }
                    Navigator.pop(context);
                    notify(
                      ProfileViewModel.profileUpdatedMessage,
                      AppColors.teal,
                    );
                  },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final action = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Choose profile photo'),
        content: Text(
          kIsWeb
              ? 'Choose a JPG or PNG image smaller than 5MB.'
              : 'Take a new photo or choose one from your device.',
        ),
        actions: <Widget>[
          if (!kIsWeb)
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'camera'),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'gallery'),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(kIsWeb ? 'Choose photo' : 'Gallery'),
          ),
          if (viewModel.avatarUrl != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'remove'),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove photo'),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'remove') {
      await _removeAvatar(context);
      return;
    }

    try {
      final image = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Use this profile photo?'),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(bytes, height: 220, fit: BoxFit.cover),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use Photo'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final error = await viewModel.uploadAvatar(
        bytes: bytes,
        fileName: image.name,
      );
      if (!context.mounted) return;
      if (error != null) {
        notify(error, AppColors.danger);
        return;
      }
      Navigator.pop(context);
      notify(ProfileViewModel.profileUpdatedMessage, AppColors.teal);
    } catch (error) {
      if (!context.mounted) return;
      notify('Could not open the selected photo: $error', AppColors.danger);
    }
  }

  Future<void> _removeAvatar(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('Your initials will be shown instead.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await viewModel.removeAvatar();
    if (!context.mounted) return;
    if (error != null) {
      notify(error, AppColors.danger);
      return;
    }
    Navigator.pop(context);
    notify(ProfileViewModel.profileUpdatedMessage, AppColors.teal);
  }

  Future<void> _language(BuildContext context) => showAppSheet<void>(
    context,
    SheetBody(
      children: <Widget>[
        ModalTitle(
          title: context.tr('Language Settings'),
          icon: Icons.language_rounded,
        ),
        const SizedBox(height: 10),
        ...<String>[
          'English (US)',
          'Bahasa Melayu',
          'Chinese (Simplified)',
          'Tamil',
        ].map(
          (String lang) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: ListTile(
              onTap: () {
                viewModel.setLanguage(lang);
                Navigator.pop(context);
                notify('Language updated to $lang.', AppColors.teal);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: viewModel.language == lang
                  ? AppColors.softBlue
                  : Colors.white,
              title: Text(
                lang,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              trailing: viewModel.language == lang
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _logout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
        title: const Text('Log out?'),
        content: const Text(
          'You can sign back in anytime to continue your journeys.',
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await authViewModel.logout();
      viewModel.logout();
      notify('Logged out successfully.', AppColors.primary);
    }
  }
}

class _PassportView extends StatelessWidget {
  const _PassportView({required this.viewModel, required this.notify});

  final ProfileViewModel viewModel;
  final void Function(String, Color) notify;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey<String>('passport-stamps'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: <Widget>[
      const SectionTitle(
        'Passport Stamps',
        subtitle: 'Your latest verified Malaysian destinations',
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.mysteryGradient,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x24173D66),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0x88FFFFFF)),
              ),
              alignment: Alignment.center,
              child: Text(
                viewModel.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    viewModel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'EXPLOREMY · DIGITAL HERITAGE PASSPORT',
                    style: TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${viewModel.latestPassportStamps.length}/5',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          const Expanded(child: Eyebrow('Latest 5 stamps')),
          FilledButton.icon(
            key: const Key('share_passport_stamps'),
            onPressed: viewModel.passportStamps.isEmpty
                ? null
                : () => _showStampPicker(context),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (viewModel.passportStamps.isEmpty)
        const AppCard(
          key: Key('empty_passport'),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.location_off_rounded,
                  size: 38,
                  color: AppColors.muted,
                ),
                SizedBox(height: 9),
                Text(
                  'No passport stamps yet',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete a verified Mystery Journey to earn your first destination stamp.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final columns = constraints.maxWidth >= 900
                ? 5
                : constraints.maxWidth >= 560
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.latestPassportStamps.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: columns == 2 ? .86 : .9,
              ),
              itemBuilder: (BuildContext context, int index) =>
                  _PassportStampCard(
                    stamp: viewModel.latestPassportStamps[index],
                    index: index,
                  ),
            );
          },
        ),
      const SizedBox(height: 12),
      if (viewModel.passportStampHistory.isNotEmpty) ...<Widget>[
        const Divider(height: 28),
        const Eyebrow('Stamp history'),
        const SizedBox(height: 4),
        const Text(
          'Older stamps stay in your collection and can still be shared.',
          style: TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        ...viewModel.passportStampHistory.asMap().entries.map(
          (entry) => _PassportHistoryTile(
            stamp: entry.value,
            colorIndex: entry.key + 5,
          ),
        ),
      ],
    ],
  );

  Future<void> _showStampPicker(BuildContext context) async {
    final selectedIds = viewModel.latestPassportStamps
        .map((stamp) => stamp.id)
        .toSet();
    final cardKey = GlobalKey();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final selected = viewModel.passportStamps
              .where((stamp) => selectedIds.contains(stamp.id))
              .toList(growable: false);
          return AlertDialog(
            backgroundColor: const Color(0xFFEEF4FA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text('Choose stamps · ${selected.length}/5'),
            content: SizedBox(
              width: 390,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (selected.isNotEmpty)
                      RepaintBoundary(
                        key: cardKey,
                        child: _ShareablePassportCard(
                          travellerName: viewModel.name,
                          stamps: selected,
                        ),
                      ),
                    const SizedBox(height: 12),
                    ...viewModel.passportStamps.map(
                      (stamp) => CheckboxListTile(
                        key: Key('share_stamp_${stamp.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedIds.contains(stamp.id),
                        title: Text(stamp.destinationName),
                        subtitle: Text(_formatStampDate(stamp.earnedAt)),
                        onChanged: (checked) {
                          if (checked == true && selectedIds.length >= 5) {
                            notify(
                              'You can share up to 5 stamps.',
                              AppColors.warning,
                            );
                            return;
                          }
                          setState(() {
                            if (checked == true) {
                              selectedIds.add(stamp.id);
                            } else {
                              selectedIds.remove(stamp.id);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  key: const Key('share_selected_stamps'),
                  onPressed: selected.isEmpty
                      ? null
                      : () =>
                            _shareStampImage(cardKey, buttonContext, selected),
                  icon: const Icon(Icons.share_rounded),
                  label: Text('Share ${selected.length}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareStampImage(
    GlobalKey cardKey,
    BuildContext buttonContext,
    List<PassportStampData> stamps,
  ) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = cardKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Passport image is not ready yet.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not generate passport image.');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (!buttonContext.mounted) return;
      final box = buttonContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: const <String>['exploremy_passport_stamps.png'],
          title: 'ExploreMY Passport Stamps',
          text: 'My ExploreMY destination stamp collection!',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
          downloadFallbackEnabled: true,
        ),
      );
      notify(
        '${stamps.length} passport stamp${stamps.length == 1 ? '' : 's'} ready to share!',
        AppColors.teal,
      );
    } catch (error) {
      notify('Could not share passport stamps: $error', AppColors.danger);
    }
  }
}

String _formatStampDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

class _PassportHistoryTile extends StatelessWidget {
  const _PassportHistoryTile({required this.stamp, required this.colorIndex});

  final PassportStampData stamp;
  final int colorIndex;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor:
              _passportSealColors[colorIndex % _passportSealColors.length].last,
          child: const Icon(Icons.location_on_rounded, color: Colors.white),
        ),
        title: Text(
          stamp.destinationName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Collected ${_formatStampDate(stamp.earnedAt)}'),
        trailing: const Icon(Icons.history_rounded, color: AppColors.muted),
      ),
    ),
  );
}

const _passportSealColors = <List<Color>>[
  <Color>[AppColors.primaryDark, AppColors.primary],
  <Color>[AppColors.tealDark, AppColors.teal],
  <Color>[Color(0xFF6A43B8), Color(0xFF8C6BE8)],
  <Color>[Color(0xFFC77A0A), AppColors.warning],
  <Color>[Color(0xFF155F7A), Color(0xFF33A6C8)],
];

class _ShareablePassportCard extends StatelessWidget {
  const _ShareablePassportCard({
    required this.travellerName,
    required this.stamps,
  });

  final String travellerName;
  final List<PassportStampData> stamps;

  @override
  Widget build(BuildContext context) => Container(
    width: 340,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppColors.mysteryGradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFFFD36A), width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'EXPLOREMY · DIGITAL HERITAGE PASSPORT',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          travellerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 9,
          runSpacing: 9,
          children: stamps.asMap().entries.map((entry) {
            final colors =
                _passportSealColors[entry.key % _passportSealColors.length];
            return SizedBox(
              width: stamps.length == 1 ? 180 : 135,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      entry.value.destinationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _formatStampDate(entry.value.earnedAt),
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

class _PassportStampCard extends StatelessWidget {
  const _PassportStampCard({required this.stamp, required this.index});

  final PassportStampData stamp;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = _passportSealColors[index % _passportSealColors.length];
    final date = _formatStampDate(stamp.earnedAt);

    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: colors.last.withValues(alpha: .35),
                width: 4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.last.withValues(alpha: .25),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xCCFFFFFF), width: 2),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                  Positioned(
                    top: 6,
                    right: 7,
                    child: Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFDE78),
                      size: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            stamp.destinationName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesView extends StatelessWidget {
  const _BadgesView({required this.viewModel, required this.notify});
  final ProfileViewModel viewModel;
  final void Function(String, Color) notify;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: <Widget>[
      const SectionTitle(
        'Achievements & Badges',
        subtitle: 'Complete challenges and earn rewards',
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: const Color(0xFF173D66),
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        ),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 27,
              backgroundColor: Color(0x33FFFFFF),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${viewModel.visibleBadges.where((b) => b.unlocked).length} badges shown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Keep discovering Malaysia’s stories.',
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 10),
                  ),
                ],
              ),
            ),
            Text(
              '${viewModel.visibleBadges.where((b) => !b.unlocked).length} locked',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 7,
        children: <String>['All', 'Unlocked', 'Locked']
            .map(
              (String s) => AppChip(
                label: s,
                selected: viewModel.badgeStatus == s,
                onTap: () => viewModel.setBadgeStatus(s),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 7),
      DropdownButtonFormField<String>(
        initialValue: viewModel.badgeCategory,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.filter_alt_rounded),
          labelText: 'Category',
        ),
        items: <String>['All Categories', 'Common', 'Rare', 'Epic', 'Legendary']
            .map(
              (String s) => DropdownMenuItem<String>(value: s, child: Text(s)),
            )
            .toList(),
        onChanged: (String? value) {
          if (value != null) viewModel.setBadgeCategory(value);
        },
      ),
      const SizedBox(height: 12),
      if (viewModel.visibleBadges.isEmpty)
        const AppCard(
          key: Key('empty_achievements'),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.filter_alt_off_rounded,
                  color: AppColors.muted,
                  size: 34,
                ),
                SizedBox(height: 9),
                Text(
                  ProfileViewModel.noAchievementsMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        ...viewModel.visibleBadges.map(
          (BadgeData b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => _badgeDetail(context, b),
              color: b.unlocked ? Colors.white : AppColors.elevated,
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: b.unlocked
                        ? AppColors.softBlue
                        : const Color(0xFFE2E7EB),
                    child: Icon(
                      b.unlocked
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_rounded,
                      color: b.unlocked ? AppColors.primary : AppColors.muted,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                b.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            AppChip(
                              label: b.rarity,
                              selected: b.unlocked,
                              selectedColor: b.rarity == 'Legendary'
                                  ? AppColors.warning
                                  : AppColors.primary,
                            ),
                          ],
                        ),
                        Text(
                          b.description,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.unlocked
                              ? 'Unlocked · +${b.xp} XP'
                              : '${b.progress} / ${b.requirementValue} progress · ${b.xp} XP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: b.unlocked
                                ? AppColors.tealDark
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _badgeDetail(
    BuildContext context,
    BadgeData b,
  ) => showAppSheet<void>(
    context,
    SheetBody(
      children: <Widget>[
        ModalTitle(
          title: b.title,
          subtitle: '${b.rarity} achievement',
          icon: b.unlocked
              ? Icons.workspace_premium_rounded
              : Icons.lock_rounded,
        ),
        const SizedBox(height: 12),
        CircleAvatar(
          radius: 50,
          backgroundColor: b.unlocked ? AppColors.softBlue : AppColors.elevated,
          child: Icon(
            b.unlocked ? Icons.military_tech_rounded : Icons.lock_rounded,
            size: 53,
            color: b.unlocked ? AppColors.primary : AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          b.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        AppCard(
          color: const Color(0xFFFFF7E5),
          borderColor: const Color(0xFFF1D38A),
          child: Column(
            children: <Widget>[
              const Eyebrow('Explore My Certificate', color: AppColors.warning),
              const SizedBox(height: 5),
              Text(
                'Awarded to ${viewModel.name}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '+${b.xp} XP · Malaysian Heritage Explorer',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              if (b.unlocked) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Unlocked ${_formatUnlockDate(b.unlockedAt)}',
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (b.unlocked)
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBadgeCard(context, b, saveOnly: true),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Save Image'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showBadgeCard(context, b),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Badge'),
                ),
              ),
            ],
          )
        else
          const OutlinedButton(onPressed: null, child: Text('Badge Locked')),
      ],
    ),
  );

  Future<void> _showBadgeCard(
    BuildContext context,
    BadgeData b, {
    bool saveOnly = false,
  }) async {
    final cardKey = GlobalKey();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFEEF4FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(saveOnly ? 'Save badge image' : 'Share achievement badge'),
        content: SingleChildScrollView(
          child: RepaintBoundary(
            key: cardKey,
            child: _ShareableBadgeCard(
              badge: b,
              travellerName: viewModel.name,
              unlockDate: _formatUnlockDate(b.unlockedAt),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (saveOnly)
            FilledButton.icon(
              onPressed: () => _saveBadgeImage(cardKey, b),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Save Image'),
            )
          else
            Builder(
              builder: (BuildContext buttonContext) => FilledButton.icon(
                onPressed: () => _shareBadgeImage(cardKey, buttonContext, b),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Badge'),
              ),
            ),
        ],
      ),
    );
  }

  Future<Uint8List> _generateBadgeImage(GlobalKey cardKey) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = cardKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Badge image is not ready yet.');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not generate the badge image.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _shareBadgeImage(
    GlobalKey cardKey,
    BuildContext buttonContext,
    BadgeData b,
  ) async {
    try {
      final bytes = await _generateBadgeImage(cardKey);
      if (!buttonContext.mounted) return;
      final box = buttonContext.findRenderObject() as RenderBox?;
      notify('Achievement badge ready to share!', AppColors.teal);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: <String>['${_badgeFileName(b)}.png'],
          title: 'ExploreMY Achievement',
          text: 'I unlocked ${b.title} in ExploreMY!',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
          downloadFallbackEnabled: true,
        ),
      );
    } catch (error) {
      notify('Could not share achievement badge: $error', AppColors.danger);
    }
  }

  Future<void> _saveBadgeImage(GlobalKey cardKey, BadgeData b) async {
    try {
      final bytes = await _generateBadgeImage(cardKey);
      await FileSaver.instance.saveAs(
        name: _badgeFileName(b),
        bytes: bytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      notify('Achievement badge image saved successfully.', AppColors.teal);
    } catch (error) {
      notify('Could not save achievement badge: $error', AppColors.danger);
    }
  }

  String _badgeFileName(BadgeData b) =>
      'exploremy_${b.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '')}';

  String _formatUnlockDate(DateTime? value) {
    if (value == null) return 'recently';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _ShareableBadgeCard extends StatelessWidget {
  const _ShareableBadgeCard({
    required this.badge,
    required this.travellerName,
    required this.unlockDate,
  });

  final BadgeData badge;
  final String travellerName;
  final String unlockDate;

  @override
  Widget build(BuildContext context) => Container(
    width: 340,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFF102E50), Color(0xFF1E5791)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFFFD36A), width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.explore_rounded, color: Colors.white, size: 25),
            SizedBox(width: 8),
            Text(
              'ExploreMY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: 106,
          height: 106,
          decoration: const BoxDecoration(
            color: Color(0x22FFFFFF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFD36A),
            size: 65,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          badge.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          badge.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFD6E2EE), height: 1.35),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x18FFFFFF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: <Widget>[
              Text(
                'Awarded to $travellerName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Unlocked $unlockDate  ·  +${badge.xp} XP',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD36A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          badge.rarity.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFFFD36A),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView({
    required this.profile,
    required this.auth,
    required this.notify,
  });
  final ProfileViewModel profile;
  final AuthViewModel auth;
  final void Function(String, Color) notify;
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool submitted = false;
  bool obscurePassword = true;
  String? loginError;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('login_screen'),
    padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
    children: <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset('assets/batu_caves.png', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Colors.transparent, Color(0xA9152536)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const Positioned(
                left: 16,
                bottom: 14,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.explore_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Explore My',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Welcome Back',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text(
        'Continue planning and discovering Malaysia',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      AppCard(
        child: Form(
          key: formKey,
          autovalidateMode: submitted
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: const Key('login_email'),
                controller: email,
                onChanged: (_) {
                  if (loginError != null) setState(() => loginError = null);
                },
                keyboardType: TextInputType.emailAddress,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required.';
                  }
                  if (!AuthViewModel.isValidEmail(value)) {
                    return 'Use a valid email such as user@domain.com.';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('login_password'),
                controller: password,
                onChanged: (_) {
                  if (loginError != null) setState(() => loginError = null);
                },
                obscureText: obscurePassword,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    key: const Key('login_password_visibility'),
                    tooltip: obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (loginError != null) ...<Widget>[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('login_error'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Text(
                      loginError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      widget.profile.setStage(ProfileStage.recover),
                  child: const Text('Forgot Password?'),
                ),
              ),
              FilledButton.icon(
                key: const Key('login_submit'),
                onPressed: widget.auth.busy ? null : _login,
                icon: widget.auth.busy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('Sign In'),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Text(
                    'Don’t have an account? ',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                  TextButton(
                    key: const Key('open_register'),
                    onPressed: () =>
                        widget.profile.setStage(ProfileStage.register),
                    child: const Text('Register Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Future<void> _login() async {
    setState(() => submitted = true);
    if (!(formKey.currentState?.validate() ?? false)) return;
    final error = await widget.auth.login(email.text, password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => loginError = error);
      widget.notify(error, AppColors.danger);
    } else {
      setState(() => loginError = null);
      widget.notify(AuthViewModel.loginSuccessMessage, AppColors.teal);
    }
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView({
    required this.profile,
    required this.auth,
    required this.notify,
  });
  final ProfileViewModel profile;
  final AuthViewModel auth;
  final void Function(String, Color) notify;
  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final formKey = GlobalKey<FormState>();
  final fields = List<TextEditingController>.generate(
    7,
    (_) => TextEditingController(),
  );
  final birthday = TextEditingController();
  DateTime? selectedBirthday;
  String? lastError;
  bool submitted = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;

  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
    birthday.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = <String>[
      'Display Name *',
      'Email Address *',
      'Password *',
      'Confirm Password *',
      'Phone Number *',
    ];
    const icons = <IconData>[
      Icons.person_outline_rounded,
      Icons.mail_outline_rounded,
      Icons.lock_outline_rounded,
      Icons.lock_outline_rounded,
      Icons.phone_outlined,
    ];
    return ListView(
      key: const Key('register_screen'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () => widget.profile.setStage(ProfileStage.login),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Expanded(
              child: SectionTitle(
                'Create New Account',
                subtitle: 'Register your ExploreMY account',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Form(
            key: formKey,
            autovalidateMode: submitted
                ? AutovalidateMode.always
                : AutovalidateMode.onUserInteraction,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < 5; i++) ...<Widget>[
                  TextFormField(
                    key: switch (i) {
                      0 => const Key('register_name'),
                      2 => const Key('register_password'),
                      3 => const Key('register_confirm_password'),
                      _ => null,
                    },
                    controller: fields[i],
                    obscureText: i == 2
                        ? obscurePassword
                        : i == 3
                        ? obscureConfirmation
                        : false,
                    keyboardType: switch (i) {
                      1 => TextInputType.emailAddress,
                      4 => TextInputType.phone,
                      _ => TextInputType.text,
                    },
                    inputFormatters: i == 4
                        ? <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ]
                        : null,
                    validator: (String? value) =>
                        _registrationFieldError(i, value ?? ''),
                    onChanged: (_) {
                      if (lastError ==
                          AuthViewModel.duplicateRegistrationMessage) {
                        setState(() => lastError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: labels[i],
                      prefixIcon: Icon(icons[i]),
                      suffixIcon: i == 2 || i == 3
                          ? IconButton(
                              key: Key(
                                i == 2
                                    ? 'register_password_visibility'
                                    : 'register_confirm_visibility',
                              ),
                              tooltip:
                                  (i == 2
                                      ? obscurePassword
                                      : obscureConfirmation)
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(() {
                                if (i == 2) {
                                  obscurePassword = !obscurePassword;
                                } else {
                                  obscureConfirmation = !obscureConfirmation;
                                }
                              }),
                              icon: Icon(
                                (i == 2 ? obscurePassword : obscureConfirmation)
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            )
                          : null,
                      helperText: i == 2
                          ? '8+ characters with an uppercase letter and symbol'
                          : i == 4
                          ? '10–11 digits without spaces or dashes'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Identification document',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<IdentityType>(
                    key: const Key('register_identity_type'),
                    segments: const <ButtonSegment<IdentityType>>[
                      ButtonSegment<IdentityType>(
                        value: IdentityType.ic,
                        icon: Icon(Icons.badge_outlined),
                        label: Text('Malaysian IC'),
                      ),
                      ButtonSegment<IdentityType>(
                        value: IdentityType.passport,
                        icon: Icon(Icons.menu_book_outlined),
                        label: Text('Passport'),
                      ),
                    ],
                    selected: <IdentityType>{widget.auth.selectedIdentityType},
                    onSelectionChanged: widget.auth.busy
                        ? null
                        : (Set<IdentityType> selection) {
                            final type = selection.first;
                            setState(() {
                              if (type == IdentityType.ic) {
                                fields[6].clear();
                              } else {
                                fields[5].clear();
                              }
                              lastError = null;
                            });
                            widget.auth.selectIdentityType(type);
                          },
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.auth.selectedIdentityType == IdentityType.ic
                      ? TextFormField(
                          key: const Key('register_ic'),
                          controller: fields[5],
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          validator: (String? value) =>
                              _identityFieldError(value ?? ''),
                          onChanged: (_) => _clearDuplicateError(),
                          decoration: const InputDecoration(
                            labelText: 'IC Number *',
                            hintText: 'e.g. 050704101234',
                            helperText: 'Enter 12 digits without dashes',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        )
                      : Column(
                          key: const Key('register_passport_fields'),
                          children: <Widget>[
                            TextFormField(
                              key: const Key('register_passport'),
                              controller: fields[6],
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9\s-]'),
                                ),
                                LengthLimitingTextInputFormatter(22),
                              ],
                              validator: (String? value) =>
                                  _identityFieldError(value ?? ''),
                              onChanged: (_) => _clearDuplicateError(),
                              decoration: const InputDecoration(
                                labelText: 'Passport Number *',
                                helperText: '5–20 letters or digits',
                                prefixIcon: Icon(Icons.menu_book_outlined),
                              ),
                            ),
                            const SizedBox(height: 9),
                            DropdownButtonFormField<String>(
                              key: const Key('register_issuing_country'),
                              initialValue: widget.auth.selectedIssuingCountry,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Issuing Country *',
                                prefixIcon: Icon(Icons.public_rounded),
                              ),
                              items: _issuingCountries.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(
                                        '${entry.value} (${entry.key})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: widget.auth.busy
                                  ? null
                                  : (String? value) {
                                      if (value != null) {
                                        widget.auth.selectIssuingCountry(value);
                                      }
                                    },
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 9),
                TextFormField(
                  key: const Key('register_birthday'),
                  controller: birthday,
                  readOnly: true,
                  onTap: _selectBirthday,
                  validator: (_) => selectedBirthday == null
                      ? 'Please select your birthday.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Birthday *',
                    hintText: 'DD/MM/YYYY',
                    helperText: 'Tap to select your date of birth',
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                ),
                const SizedBox(height: 13),
                FilledButton.icon(
                  key: const Key('register_submit'),
                  onPressed: widget.auth.busy ? null : _register,
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Complete Registration'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _register() async {
    setState(() {
      submitted = true;
      lastError = null;
    });
    formKey.currentState?.validate();
    final error = await widget.auth.register(
      name: fields[0].text,
      email: fields[1].text,
      password: fields[2].text,
      confirmation: fields[3].text,
      phone: fields[4].text,
      identityNumber: widget.auth.selectedIdentityType == IdentityType.ic
          ? fields[5].text
          : fields[6].text,
      birthday: selectedBirthday,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => lastError = error);
      formKey.currentState?.validate();
      widget.notify(error, AppColors.danger);
    } else {
      if (widget.auth.isAuthenticated) {
        widget.notify(AuthViewModel.registrationSuccessMessage, AppColors.teal);
      } else {
        widget.profile.setStage(ProfileStage.verifyEmail);
        widget.notify(AuthViewModel.registrationSuccessMessage, AppColors.teal);
      }
    }
  }

  String? _registrationFieldError(int index, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '${_registrationFieldName(index)} is required.';
    if (index == 0 && (trimmed.length < 3 || trimmed.length > 30)) {
      return 'Display name must contain 3–30 characters.';
    }
    if (index == 1 && !AuthViewModel.isValidEmail(trimmed)) {
      return 'Use a valid email such as user@domain.com.';
    }
    if (index == 2 && !AuthViewModel.isValidPassword(value)) {
      return 'Use 8+ characters with an uppercase letter and symbol.';
    }
    if (index == 3 && value != fields[2].text) {
      return 'Passwords do not match.';
    }
    if (index == 4 && !AuthViewModel.isValidPhone(trimmed)) {
      return 'Phone number must contain 10–11 digits.';
    }
    if (index == 1 && lastError == AuthViewModel.duplicateRegistrationMessage) {
      return 'Email may already be registered.';
    }
    return null;
  }

  String _registrationFieldName(int index) => const <String>[
    'Display name',
    'Email',
    'Password',
    'Confirm password',
    'Phone number',
  ][index];

  String? _identityFieldError(String value) {
    if (value.trim().isEmpty) {
      return widget.auth.selectedIdentityType == IdentityType.ic
          ? 'IC number is required.'
          : 'Passport number is required.';
    }
    if (widget.auth.selectedIdentityType == IdentityType.ic &&
        !AuthViewModel.isValidIc(value)) {
      return 'IC number must contain exactly 12 digits.';
    }
    if (widget.auth.selectedIdentityType == IdentityType.passport &&
        !AuthViewModel.isValidPassport(value)) {
      return 'Passport number must contain 5–20 letters or digits.';
    }
    if (lastError == AuthViewModel.duplicateRegistrationMessage) {
      return 'Identification number may already be registered.';
    }
    return null;
  }

  void _clearDuplicateError() {
    if (lastError == AuthViewModel.duplicateRegistrationMessage) {
      setState(() => lastError = null);
    }
  }

  static const Map<String, String> _issuingCountries = <String, String>{
    'MY': 'Malaysia',
    'SG': 'Singapore',
    'CN': 'China',
    'IN': 'India',
    'ID': 'Indonesia',
    'TH': 'Thailand',
    'PH': 'Philippines',
    'VN': 'Vietnam',
    'BN': 'Brunei',
    'MM': 'Myanmar',
    'JP': 'Japan',
    'KR': 'South Korea',
    'AU': 'Australia',
    'GB': 'United Kingdom',
    'US': 'United States',
  };

  Future<void> _selectBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          selectedBirthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select your birthday',
    );
    if (selected == null || !mounted) return;

    setState(() {
      selectedBirthday = selected;
      final day = selected.day.toString().padLeft(2, '0');
      final month = selected.month.toString().padLeft(2, '0');
      birthday.text = '$day/$month/${selected.year}';
    });
  }
}

class _VerifyEmailView extends StatelessWidget {
  const _VerifyEmailView({
    required this.profile,
    required this.auth,
    required this.notify,
  });
  final ProfileViewModel profile;
  final AuthViewModel auth;
  final void Function(String, Color) notify;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
    children: <Widget>[
      const Icon(
        Icons.mark_email_unread_rounded,
        size: 64,
        color: AppColors.primary,
      ),
      const SizedBox(height: 14),
      Text(
        'Verify your email',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 6),
      Text(
        'We sent a confirmation link to\n${auth.pendingVerificationEmail ?? 'your email'}.\n\nOpen the link, then return here and sign in.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (auth.verificationError != null) ...<Widget>[
              Container(
                key: const Key('verification_link_error'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Text(
                  auth.verificationError!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              key: const Key('resend_verification'),
              onPressed: auth.canResendVerification
                  ? () => _resend(context)
                  : null,
              icon: auth.busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(auth.verificationResendLabel),
            ),
            TextButton(
              onPressed: auth.busy
                  ? null
                  : () {
                      auth.cancelVerification();
                      profile.setStage(ProfileStage.login);
                    },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _resend(BuildContext context) async {
    final error = await auth.resendVerificationEmail();
    if (!context.mounted) return;
    notify(
      error ?? 'A new confirmation email was sent.',
      error == null ? AppColors.teal : AppColors.danger,
    );
  }
}

class _RecoverView extends StatefulWidget {
  const _RecoverView({
    required this.profile,
    required this.auth,
    required this.notify,
  });
  final ProfileViewModel profile;
  final AuthViewModel auth;
  final void Function(String, Color) notify;
  @override
  State<_RecoverView> createState() => _RecoverViewState();
}

class _RecoverViewState extends State<_RecoverView> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  bool submitted = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
    children: <Widget>[
      Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              widget.auth.resetRecovery();
              widget.profile.setStage(ProfileStage.login);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: SectionTitle(
              'Reset Password',
              subtitle: 'Password recovery',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      AppCard(
        child: widget.auth.recoverySent
            ? Column(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFE9FAF4),
                    child: Icon(
                      Icons.mark_email_read_rounded,
                      color: AppColors.teal,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Reset Link Sent!',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Recovery instructions were sent to ${email.text}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      widget.auth.resetRecovery();
                      widget.profile.setStage(ProfileStage.login);
                    },
                    child: const Text('Back to Login'),
                  ),
                ],
              )
            : Form(
                key: formKey,
                autovalidateMode: submitted
                    ? AutovalidateMode.always
                    : AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Enter your registered email address to receive a password reset link.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required.';
                        }
                        if (!AuthViewModel.isValidEmail(value)) {
                          return 'Use a valid email such as user@domain.com.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Registered Email *',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: widget.auth.busy ? null : _sendResetLink,
                      child: const Text('Send Password Reset Link'),
                    ),
                  ],
                ),
              ),
      ),
    ],
  );

  Future<void> _sendResetLink() async {
    setState(() => submitted = true);
    if (!(formKey.currentState?.validate() ?? false)) return;
    final error = await widget.auth.recover(email.text);
    if (!mounted) return;
    widget.notify(
      error ?? AuthViewModel.resetSentMessage,
      error == null ? AppColors.teal : AppColors.danger,
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView({
    required this.profile,
    required this.auth,
    required this.notify,
  });

  final ProfileViewModel profile;
  final AuthViewModel auth;
  final void Function(String, Color) notify;

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool submitted = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('reset_password_screen'),
    padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
    children: <Widget>[
      Row(
        children: <Widget>[
          IconButton(
            onPressed: widget.auth.busy ? null : _backToLogin,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: SectionTitle(
              'Create New Password',
              subtitle: 'Secure your account',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      AppCard(
        child: widget.auth.isPasswordRecovery
            ? Form(
                key: formKey,
                autovalidateMode: submitted
                    ? AutovalidateMode.always
                    : AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Use at least 8 characters with an uppercase letter and a special symbol. Spaces are not allowed.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('reset_new_password'),
                      controller: password,
                      obscureText: obscurePassword,
                      validator: _passwordValidator,
                      decoration: InputDecoration(
                        labelText: 'New Password *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('reset_confirm_password'),
                      controller: confirmation,
                      obscureText: obscureConfirmation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password.';
                        }
                        if (value != password.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password *',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscureConfirmation = !obscureConfirmation,
                          ),
                          icon: Icon(
                            obscureConfirmation
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      key: const Key('reset_password_submit'),
                      onPressed: widget.auth.busy ? null : _submit,
                      child: widget.auth.busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                  ],
                ),
              )
            : Column(
                children: <Widget>[
                  const Icon(
                    Icons.link_off_rounded,
                    size: 42,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.auth.recoveryError ??
                        AuthViewModel.invalidRecoverySessionMessage,
                    key: const Key('reset_password_error'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _backToLogin,
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
      ),
    ],
  );

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'New password is required.';
    if (!AuthViewModel.isValidPassword(value)) {
      return 'Use 8+ characters, uppercase and special symbol; no spaces.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (!(formKey.currentState?.validate() ?? false)) return;
    final error = await widget.auth.resetPassword(
      password.text,
      confirmation.text,
    );
    if (!mounted) return;
    if (error != null) {
      widget.notify(error, AppColors.danger);
      return;
    }
    widget.profile.setStage(ProfileStage.login);
    widget.notify(AuthViewModel.resetSuccessMessage, AppColors.teal);
  }

  Future<void> _backToLogin() async {
    await widget.auth.cancelPasswordRecovery();
    widget.profile.setStage(ProfileStage.login);
  }
}
