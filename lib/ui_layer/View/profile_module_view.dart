import 'package:flutter/material.dart';

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
      ProfileStage.recover => _RecoverView(
        profile: viewModel,
        auth: authViewModel,
        notify: notify,
      ),
      ProfileStage.dashboard => _Dashboard(
        viewModel: viewModel,
        notify: notify,
      ),
    },
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.viewModel, required this.notify});
  final ProfileViewModel viewModel;
  final void Function(String, Color) notify;
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey<String>('profile-dashboard'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(
            child: SectionTitle('Profile', subtitle: 'Your travel profile'),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => _editProfile(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
          ),
        ],
      ),
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
                    const InitialsAvatar(
                      'AM',
                      radius: 40,
                      color: AppColors.softBlue,
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Next level: Cultural Heritage Master',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Keep exploring to unlock your next badge',
                        style: TextStyle(fontSize: 9, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${((viewModel.xp / 2000) * 100).round()}%',
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
                value: viewModel.xp / 2000,
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
              'Edit profile',
              'Photo, name and travel bio',
              AppColors.primary,
              () => _editProfile(context),
            ),
            const Divider(height: 1),
            _action(
              Icons.workspace_premium_rounded,
              'Travel badges',
              'Milestones, certificate and rewards',
              AppColors.warning,
              () => viewModel.setStage(ProfileStage.badges),
              key: const Key('open_badges'),
            ),
            const Divider(height: 1),
            _action(
              Icons.language_rounded,
              'Language',
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
        label: const Text('Log out'),
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
          const ModalTitle(
            title: 'Edit Profile & Avatar',
            subtitle: 'Local demo profile',
            icon: Icons.edit_rounded,
          ),
          const SizedBox(height: 10),
          const Center(
            child: Stack(
              children: <Widget>[
                InitialsAvatar('AM', radius: 42, color: AppColors.softBlue),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const <Widget>[
              InitialsAvatar('AM', radius: 18, color: Color(0xFFDDEEFF)),
              SizedBox(width: 7),
              InitialsAvatar('EX', radius: 18, color: Color(0xFFE9FAF4)),
              SizedBox(width: 7),
              InitialsAvatar('MY', radius: 18, color: Color(0xFFFFF1DB)),
            ],
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
            onPressed: () {
              final error = viewModel.updateProfile(name.text, bio.text);
              if (error != null) {
                notify(error, AppColors.danger);
                return;
              }
              Navigator.pop(context);
              notify('Profile & avatar updated successfully!', AppColors.teal);
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
    name.dispose();
    bio.dispose();
  }

  Future<void> _language(BuildContext context) => showAppSheet<void>(
    context,
    SheetBody(
      children: <Widget>[
        const ModalTitle(
          title: 'Language Settings',
          icon: Icons.language_rounded,
        ),
        const SizedBox(height: 10),
        ...<String>[
          'English (US)',
          'Bahasa Melayu',
          'Chinese (Simplified)',
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
      viewModel.logout();
      notify('Logged out successfully.', AppColors.primary);
    }
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
      Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back to profile',
            onPressed: () => viewModel.setStage(ProfileStage.dashboard),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: SectionTitle(
              'Travel Badges',
              subtitle: 'Your digital heritage passport',
            ),
          ),
        ],
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
                children: const <Widget>[
                  Text(
                    '3 badges unlocked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Keep discovering Malaysia’s stories.',
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 10),
                  ),
                ],
              ),
            ),
            const Text(
              '1 locked',
              style: TextStyle(
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
        initialValue: 'All Categories',
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.filter_alt_rounded),
          labelText: 'Category',
        ),
        items:
            <String>[
                  'All Categories',
                  'Legendary',
                  'Recent',
                  'Explore',
                  'Milestone',
                  'Heritage',
                ]
                .map(
                  (String s) =>
                      DropdownMenuItem<String>(value: s, child: Text(s)),
                )
                .toList(),
        onChanged: (_) {},
      ),
      const SizedBox(height: 12),
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
                            : '0 / 1 progress · ${b.xp} XP',
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (b.unlocked)
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _share(context, b);
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Achievement'),
          )
        else
          const OutlinedButton(onPressed: null, child: Text('Badge Locked')),
      ],
    ),
  );

  Future<void> _share(BuildContext context, BadgeData b) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF152231),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: const Icon(
        Icons.auto_awesome_rounded,
        color: AppColors.warning,
        size: 36,
      ),
      title: Text(b.title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircleAvatar(
            radius: 38,
            backgroundColor: Color(0x332F80ED),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            b.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCDD7E0)),
          ),
          const SizedBox(height: 10),
          Text(
            'Awarded to ${viewModel.name} · +${b.xp} XP',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            notify('Badge card saved and ready to share.', AppColors.teal);
          },
          child: const Text('Save / Share'),
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
  final email = TextEditingController(text: 'explorer@gmail.com');
  final password = TextEditingController(text: 'Password123!');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('login_email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('login_password'),
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password *',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.profile.setStage(ProfileStage.recover),
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
    ],
  );
  Future<void> _login() async {
    final error = await widget.auth.login(email.text, password.text);
    if (!mounted) return;
    if (error != null) {
      widget.notify(error, AppColors.danger);
    } else {
      widget.profile.authenticated();
      widget.notify('Login successful. Welcome back!', AppColors.teal);
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
  final fields = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
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
      'IC Number *',
    ];
    const icons = <IconData>[
      Icons.person_outline_rounded,
      Icons.mail_outline_rounded,
      Icons.lock_outline_rounded,
      Icons.lock_outline_rounded,
      Icons.phone_outlined,
      Icons.badge_outlined,
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
                subtitle: 'Local demo registration',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: <Widget>[
              for (var i = 0; i < fields.length; i++) ...<Widget>[
                TextField(
                  key: i == 0 ? const Key('register_name') : null,
                  controller: fields[i],
                  obscureText: i == 2 || i == 3,
                  keyboardType: i == 1
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: labels[i],
                    prefixIcon: Icon(icons[i]),
                  ),
                ),
                const SizedBox(height: 9),
              ],
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Birthday',
                  prefixIcon: Icon(Icons.cake_outlined),
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
      ],
    );
  }

  Future<void> _register() async {
    final error = await widget.auth.register(
      name: fields[0].text,
      email: fields[1].text,
      password: fields[2].text,
      confirmation: fields[3].text,
      phone: fields[4].text,
      ic: fields[5].text,
    );
    if (!mounted) return;
    if (error != null) {
      widget.notify(error, AppColors.danger);
    } else {
      widget.profile.authenticated(name: fields[0].text);
      widget.notify('Account registered successfully!', AppColors.teal);
    }
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
  final email = TextEditingController();
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Enter your registered email address to receive a local demo reset confirmation.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Registered Email *',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final error = widget.auth.recover(email.text);
                      if (error != null) {
                        widget.notify(error, AppColors.danger);
                      } else {
                        widget.notify(
                          'Password reset link sent.',
                          AppColors.teal,
                        );
                      }
                    },
                    child: const Text('Send Password Reset Link'),
                  ),
                ],
              ),
      ),
    ],
  );
}
