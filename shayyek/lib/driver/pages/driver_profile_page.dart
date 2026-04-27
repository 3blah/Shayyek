import 'package:flutter/material.dart';

import '../../app_text.dart';
import '../../theme_controller.dart';
import '../services/driver_task_service.dart';
import '../ui/driver_shared_widgets.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({
    super.key,
    required this.user,
    required this.preferences,
    required this.onSave,
    required this.onLogout,
  });

  final DriverUserContext? user;
  final DriverPreferences preferences;
  final Future<void> Function({
    required String name,
    required String phone,
    required DriverPreferences preferences,
  }) onSave;
  final Future<void> Function() onLogout;

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late DriverPreferences _preferences;

  bool _saving = false;
  bool _settingsReady = false;
  String _themePreference = 'system';
  String _localePreference = 'system';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _preferences = widget.preferences;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsReady) {
      return;
    }

    final controller = ThemeScope.maybeOf(context);
    _themePreference = controller?.themePreference ?? 'system';
    _localePreference = controller?.localePreference ?? 'system';
    _settingsReady = true;
  }

  @override
  void didUpdateWidget(covariant DriverProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.name != widget.user?.name) {
      _nameController.text = widget.user?.name ?? '';
    }
    if (oldWidget.user?.phone != widget.user?.phone) {
      _phoneController.text = widget.user?.phone ?? '';
    }
    if (oldWidget.preferences != widget.preferences) {
      _preferences = widget.preferences;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final controller = ThemeScope.maybeOf(context);
      final effectiveLanguageCode =
          controller?.effectiveLanguageCode ?? _preferences.language;
      final languageToStore = _localePreference == 'system'
          ? effectiveLanguageCode
          : _localePreference;

      if (widget.user != null) {
        await widget.onSave(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          preferences: _preferences.copyWith(language: languageToStore),
        );
      }

      if (controller != null) {
        await controller.setThemePreference(_themePreference);
        await controller.setLocalePreference(_localePreference);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.of(
              context,
              ar: 'تم حفظ الإعدادات بنجاح.',
              en: 'Settings saved successfully.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = widget.user == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        DriverTopHeader(
          title: AppText.of(
            context,
            ar: 'الحساب والإعدادات',
            en: 'Profile & Settings',
          ),
          subtitle: AppText.of(
            context,
            ar: 'تحكم باللغة والثيم من هنا فقط.',
            en: 'Manage language and theme from here only.',
          ),
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 18),
        if (isGuest)
          DriverInfoCard(
            title: AppText.of(
              context,
              ar: 'وضع الضيف',
              en: 'Guest Mode',
            ),
            body: AppText.of(
              context,
              ar: 'يمكنك تعديل لغة التطبيق والثيم الآن، لكن حفظ الملف الشخصي يحتاج تسجيل دخول.',
              en: 'You can change app language and theme now, but saving profile data requires sign in.',
            ),
            icon: Icons.travel_explore_rounded,
          ),
        if (!isGuest) ...[
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppText.of(context, ar: 'الاسم', en: 'Name'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: AppText.of(context, ar: 'الهاتف', en: 'Phone'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
        ],
        DriverSectionTitle(
          AppText.of(
            context,
            ar: 'مظهر التطبيق',
            en: 'App Appearance',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _themePreference,
          decoration: InputDecoration(
            labelText: AppText.of(
              context,
              ar: 'الثيم',
              en: 'Theme',
            ),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(
                AppText.of(context, ar: 'حسب النظام', en: 'Follow system'),
              ),
            ),
            DropdownMenuItem(
              value: 'light',
              child: Text(
                AppText.of(context, ar: 'فاتح', en: 'Light'),
              ),
            ),
            DropdownMenuItem(
              value: 'dark',
              child: Text(
                AppText.of(context, ar: 'داكن', en: 'Dark'),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _themePreference = value);
            ThemeScope.of(context).setThemePreference(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _localePreference,
          decoration: InputDecoration(
            labelText: AppText.of(
              context,
              ar: 'اللغة',
              en: 'Language',
            ),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(
                AppText.of(context, ar: 'لغة الجهاز', en: 'Device language'),
              ),
            ),
            DropdownMenuItem(
              value: 'ar',
              child: Text(
                AppText.of(context, ar: 'العربية', en: 'Arabic'),
              ),
            ),
            const DropdownMenuItem(
              value: 'en',
              child: Text('English'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _localePreference = value);
            ThemeScope.of(context).setLocalePreference(value);
          },
        ),
        const SizedBox(height: 18),
        DriverSectionTitle(
          AppText.of(
            context,
            ar: 'تفضيلات السائق',
            en: 'Driver Preferences',
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          value: _preferences.notifyPush,
          title: Text(
            AppText.of(context, ar: 'إشعارات Push', en: 'Push notifications'),
          ),
          onChanged: (value) => setState(
            () => _preferences = _preferences.copyWith(notifyPush: value),
          ),
        ),
        SwitchListTile(
          value: _preferences.notifyEmail,
          title: Text(
            AppText.of(context,
                ar: 'إشعارات البريد', en: 'Email notifications'),
          ),
          onChanged: (value) => setState(
            () => _preferences = _preferences.copyWith(notifyEmail: value),
          ),
        ),
        SwitchListTile(
          value: _preferences.filterAccessible,
          title: Text(
            AppText.of(context,
                ar: 'مواقف Accessible فقط', en: 'Accessible only'),
          ),
          onChanged: (value) => setState(
            () => _preferences = _preferences.copyWith(filterAccessible: value),
          ),
        ),
        SwitchListTile(
          value: _preferences.filterEv,
          title: Text(
            AppText.of(context, ar: 'مواقف EV فقط', en: 'EV only'),
          ),
          onChanged: (value) => setState(
            () => _preferences = _preferences.copyWith(filterEv: value),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                AppText.of(
                  context,
                  ar: 'الحد الأقصى للبقاء',
                  en: 'Maximum stay',
                ),
              ),
            ),
            Text(
              AppText.of(
                context,
                ar: '${_preferences.filterMaxStayMin} دقيقة',
                en: '${_preferences.filterMaxStayMin} min',
              ),
            ),
          ],
        ),
        Slider(
          value: _preferences.filterMaxStayMin.toDouble(),
          min: 30,
          max: 360,
          divisions: 11,
          onChanged: (value) => setState(
            () => _preferences = _preferences.copyWith(
              filterMaxStayMin: value.round(),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                AppText.of(
                  context,
                  ar: 'الحد الأعلى للسعر',
                  en: 'Maximum price',
                ),
              ),
            ),
            Text(_preferences.filterPriceMax.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: _preferences.filterPriceMax,
          min: 1,
          max: 20,
          divisions: 19,
          onChanged: (value) => setState(
            () => _preferences = _preferences.copyWith(filterPriceMax: value),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                AppText.of(
                  context,
                  ar: 'المسافة الافتراضية',
                  en: 'Default distance',
                ),
              ),
            ),
            Text(
              AppText.of(
                context,
                ar: '${_preferences.defaultDistanceKm.toStringAsFixed(1)} كم',
                en: '${_preferences.defaultDistanceKm.toStringAsFixed(1)} km',
              ),
            ),
          ],
        ),
        Slider(
          value: _preferences.defaultDistanceKm,
          min: 1,
          max: 10,
          divisions: 18,
          onChanged: (value) => setState(
            () =>
                _preferences = _preferences.copyWith(defaultDistanceKm: value),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            AppText.of(
              context,
              ar: 'حفظ الإعدادات',
              en: 'Save Settings',
            ),
          ),
        ),
        if (!isGuest) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              widget.onLogout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              AppText.of(
                context,
                ar: 'تسجيل الخروج',
                en: 'Sign Out',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
