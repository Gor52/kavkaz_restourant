import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/di.dart';
import '../../../app/auth_required_navigation.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/in_app_notification_sync_service.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../features/admin/presentation/admin_dashboard_page.dart';
import '../../../features/booking/presentation/booking_page.dart';
import '../../../features/cart/presentation/cart_page.dart';
import '../../../features/home/presentation/home_page.dart';
import '../../../features/menu/presentation/menu_page.dart';
import '../../../features/profile/presentation/profile_page.dart';
import '../../../shared/enums/user_role.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _cartRefreshKey = 0;
  UserRole _role = UserRole.guest;
  final Set<int> _initializedTabs = <int>{0};

  String _shellDisplayName = 'Гость';
  String _shellFullName = '';

  int? _customerBonusBalance;
  bool _bonusLoading = false;
  bool _bonusLoadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapShell();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      InAppNotificationSyncService.instance.refresh();
    }
  }

  Future<void> _bootstrapShell() async {
    await _loadRoleAndAuthState();
    await _loadShellUserProfile();
    await _loadShellBonuses();
    await InAppNotificationSyncService.instance.refresh();
  }

  Future<void> _loadShellBonuses() async {
    if (_role.isStaff) {
      if (!mounted) return;
      setState(() {
        _customerBonusBalance = null;
        _bonusLoading = false;
        _bonusLoadFailed = false;
      });
      return;
    }
    final authorized = await AppDi.sessionService.isAuthorized();
    if (!mounted) return;
    if (!authorized) {
      setState(() {
        _customerBonusBalance = null;
        _bonusLoading = false;
        _bonusLoadFailed = false;
      });
      return;
    }

    setState(() {
      _bonusLoading = true;
      _bonusLoadFailed = false;
    });

    try {
      final balance = await AppDi.profileRepository.getBonusBalance();
      if (!mounted) return;
      setState(() {
        _customerBonusBalance = balance < 0 ? 0 : balance;
        _bonusLoading = false;
        _bonusLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customerBonusBalance = null;
        _bonusLoading = false;
        _bonusLoadFailed = true;
      });
    }
  }

  String _formatBonusAmount(int value) {
    return NumberFormat.decimalPattern('ru_RU').format(value);
  }

  ({IconData icon, String text, Color iconColor}) _headerBonusLine() {
    if (_role.isStaff) {
      return (
        icon: Icons.admin_panel_settings_outlined,
        text: _role.isAdmin ? 'Администратор' : 'Менеджер',
        iconColor: AppColors.textHint,
      );
    }
    if (_shellDisplayName == 'Гость') {
      return (
        icon: Icons.stars_outlined,
        text: 'Войдите, чтобы копить бонусы',
        iconColor: AppColors.accent.withValues(alpha: 0.95),
      );
    }
    if (_bonusLoading) {
      return (
        icon: Icons.workspace_premium_outlined,
        text: 'Загрузка бонусов…',
        iconColor: AppColors.textHint,
      );
    }
    if (_bonusLoadFailed) {
      return (
        icon: Icons.error_outline_rounded,
        text: 'Не удалось загрузить бонусы',
        iconColor: AppColors.error,
      );
    }
    final b = _customerBonusBalance ?? 0;
    return (
      icon: Icons.workspace_premium_rounded,
      text: '${_formatBonusAmount(b)} бонусов доступно',
      iconColor: AppColors.accent.withValues(alpha: 0.95),
    );
  }

  int get _profileTabIndex => _role.isStaff ? 2 : 4;

  int? get _cartTabIndex => _role.isStaff ? null : 2;

  void _normalizeTabIndexForRole() {
    if (_role.isStaff) {
      switch (_currentIndex) {
        case 2:
        case 3:
          _currentIndex = 0;
        case 4:
          _currentIndex = 2;
        case 5:
          _currentIndex = 3;
      }
    } else {
      switch (_currentIndex) {
        case 2:
          _currentIndex = 4;
        case 3:
          _currentIndex = 5;
      }
    }
  }

  Future<void> _loadRoleAndAuthState() async {
    final roleTitle = await AppDi.sessionService.getRole();
    final isAuthorized = await AppDi.sessionService.isAuthorized();
    if (!mounted) return;
    setState(() {
      _role = UserRole.fromTitle(roleTitle);
      _normalizeTabIndexForRole();
      if (!isAuthorized && _currentIndex >= 2) {
        _currentIndex = 0;
      }
    });
  }

  Future<void> _loadShellUserProfile() async {
    final authorized = await AppDi.sessionService.isAuthorized();
    if (!mounted) return;
    if (!authorized) {
      setState(() {
        _shellDisplayName = 'Гость';
        _shellFullName = '';
      });
      await _loadShellBonuses();
      return;
    }
    try {
      final user = await AppDi.profileRepository.getProfile();
      if (!mounted) return;
      setState(() {
        _shellFullName = user.fullName.trim();
        _shellDisplayName =
            _shellFullName.isEmpty ? 'Пользователь' : _shellFullName;
      });
    } catch (_) {
      if (!mounted) return;
      final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
      setState(() {
        _shellFullName = '';
        _shellDisplayName =
            role == UserRole.guest ? 'Гость' : 'Пользователь';
      });
    }
    if (mounted) await _loadShellBonuses();
  }

  static String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      final w = parts.first;
      if (w.length >= 2) return w.substring(0, 2).toUpperCase();
      return w.isNotEmpty ? w[0].toUpperCase() : '';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _openProfileFromHeader() async {
    final profileIndex = _profileTabIndex;
    if (!await _canOpenTab(profileIndex)) return;
    if (!mounted) return;
    setState(() {
      _initializedTabs.add(profileIndex);
      _currentIndex = profileIndex;
    });
    await _loadShellUserProfile();
    await _loadShellBonuses();
  }

  Future<bool> _canOpenTab(int index) async {
    final requiresAuth = index >= 2;
    if (!requiresAuth) return true;

    final isAuthorized = await AppDi.sessionService.isAuthorized();
    if (isAuthorized) return true;
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Для этого действия требуется вход')),
    );
    context.push(buildAuthRequiredLocation(from: '/shell'));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showAdminTab = _role.isAdmin || _role.isManager;
    final showCartAndBooking = !_role.isStaff;
    final bonusLine = _headerBonusLine();

    final pages = <Widget>[
      HomePage(
        hideCustomerActions: _role.isStaff,
        onOpenMenu: () {
          setState(() {
            _initializedTabs.add(1);
            _currentIndex = 1;
          });
        },
      ),
      const MenuPage(),
      if (showCartAndBooking) CartPage(key: ValueKey(_cartRefreshKey)),
      if (showCartAndBooking) const BookingPage(),
      const ProfilePage(),
      if (showAdminTab) const AdminDashboardPage(),
    ];

    final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ShellHeader(
              displayName: _shellDisplayName,
              subtitleText: bonusLine.text,
              subtitleIcon: bonusLine.icon,
              subtitleIconColor: bonusLine.iconColor,
              initials: _shellFullName.isEmpty ? null : _initials(_shellFullName),
              isGuest: _shellDisplayName == 'Гость',
              onProfileTap: () {
                _openProfileFromHeader();
              },
              onNotificationsTap: () => context.push('/notifications'),
            ),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: List<Widget>.generate(
                  pages.length,
                  (index) => _initializedTabs.contains(index)
                      ? pages[index]
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: safeIndex,
        showAdminTab: showAdminTab,
        showCartAndBooking: showCartAndBooking,
        onTap: (value) async {
          if (!await _canOpenTab(value)) return;
          if (!mounted) return;
          setState(() {
            _initializedTabs.add(value);
            if (value == _cartTabIndex) {
              _cartRefreshKey++;
            }
            _currentIndex = value;
          });
          if (value == _profileTabIndex) {
            await _loadShellUserProfile();
            await _loadShellBonuses();
          }
        },
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.displayName,
    required this.subtitleText,
    required this.subtitleIcon,
    required this.subtitleIconColor,
    required this.initials,
    required this.isGuest,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final String displayName;
  final String subtitleText;
  final IconData subtitleIcon;
  final Color subtitleIconColor;
  final String? initials;
  final bool isGuest;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              AppColors.card,
              AppColors.accentSoft.withValues(alpha: 0.55),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.92),
                    AppColors.primaryDark,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: initials == null || initials!.isEmpty
                  ? Icon(
                      isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 26,
                    )
                  : Text(
                      initials!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    softWrap: true,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.22,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.15,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          subtitleIcon,
                          size: 16,
                          color: subtitleIconColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNotificationsTap,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.14),
                        AppColors.accent.withValues(alpha: 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}