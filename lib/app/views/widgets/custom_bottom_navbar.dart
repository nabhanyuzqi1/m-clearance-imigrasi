import 'package:flutter/material.dart';
import '../../services/logging_service.dart';
import '../../config/theme.dart';
import '../../localization/app_strings.dart';

class NavigationItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final Color? color;

  const NavigationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.color,
  });
}

class CustomBottomNavbar extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double? elevation;
  final bool showSelectedLabels;
  final bool showUnselectedLabels;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final double? iconSize;
  final BottomNavigationBarType type;
  final String? languageCode;

  const CustomBottomNavbar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation,
    this.showSelectedLabels = true,
    this.showUnselectedLabels = true,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
    this.iconSize,
    this.type = BottomNavigationBarType.fixed,
    this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building CustomBottomNavbar with currentIndex: $currentIndex');
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultIconSize = iconSize ?? screenWidth * 0.06;
    final defaultSelectedLabelStyle = TextStyle(
      fontSize: screenWidth * 0.03,
      fontWeight: FontWeight.w500,
    );
    final defaultUnselectedLabelStyle = TextStyle(
      fontSize: screenWidth * 0.03,
    );

    return BottomNavigationBar(
      type: type,
      items: items.map((item) {
        // Get localized label if language code is provided
        final localizedLabel = languageCode != null
            ? _getLocalizedLabel(context, item.label, languageCode!)
            : item.label;

        return BottomNavigationBarItem(
          icon: Icon(
            item.icon,
            size: defaultIconSize,
            color: unselectedItemColor ?? AppTheme.onSurface.withAlpha(102), // 0.4 * 255
          ),
          activeIcon: Icon(
            item.activeIcon ?? item.icon,
            size: defaultIconSize,
            color: selectedItemColor ?? AppTheme.primaryColor,
          ),
          label: localizedLabel,
          backgroundColor: item.color,
        );
      }).toList(),
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: backgroundColor ?? AppTheme.surfaceColor,
      selectedItemColor: selectedItemColor ?? AppTheme.primaryColor,
      unselectedItemColor: unselectedItemColor ?? AppTheme.onSurface.withAlpha(102), // 0.4 * 255
      showSelectedLabels: showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels,
      selectedLabelStyle: selectedLabelStyle ?? defaultSelectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle ?? defaultUnselectedLabelStyle,
      elevation: elevation ?? 8,
    );
  }

  String _getLocalizedLabel(BuildContext context, String label, String languageCode) {
    // Map hardcoded labels to localized keys
    final labelMap = {
      'Home': {'screenKey': 'userHome', 'stringKey': 'home'},
      'History': {'screenKey': 'userHistory', 'stringKey': 'history'},
      'Settings': {'screenKey': 'userProfile', 'stringKey': 'settings'},
      'Reports': {'screenKey': 'adminHome', 'stringKey': 'report'},
    };

    final mapping = labelMap[label];
    if (mapping != null) {
      return AppStrings.tr(
        context: context,
        screenKey: mapping['screenKey']!,
        stringKey: mapping['stringKey']!,
        langCode: languageCode,
      );
    }

    return label; // Fallback to original label
  }
}

// Predefined navigation items for common use cases
class NavigationItems {
  static List<NavigationItem> userItems = [
    const NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_filled,
    ),
    const NavigationItem(
      label: 'History',
      icon: Icons.history,
      activeIcon: Icons.history,
    ),
    const NavigationItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  static List<NavigationItem> officerItems = [
    const NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_filled,
    ),
    const NavigationItem(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      activeIcon: Icons.assessment,
    ),
    const NavigationItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  static List<NavigationItem> adminItems = [
    const NavigationItem(
      label: 'Home',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    const NavigationItem(
      label: 'Reports',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
    ),
    const NavigationItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];
}