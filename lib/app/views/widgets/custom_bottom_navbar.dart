import 'package:flutter/material.dart';

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
  });

  @override
  Widget build(BuildContext context) {
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
        return BottomNavigationBarItem(
          icon: Icon(
            item.icon,
            size: defaultIconSize,
            color: unselectedItemColor ?? Colors.grey,
          ),
          activeIcon: Icon(
            item.activeIcon ?? item.icon,
            size: defaultIconSize,
            color: selectedItemColor ?? Theme.of(context).primaryColor,
          ),
          label: item.label,
          backgroundColor: item.color,
        );
      }).toList(),
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: backgroundColor ?? Colors.white,
      selectedItemColor: selectedItemColor ?? Theme.of(context).primaryColor,
      unselectedItemColor: unselectedItemColor ?? Colors.grey,
      showSelectedLabels: showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels,
      selectedLabelStyle: selectedLabelStyle ?? defaultSelectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle ?? defaultUnselectedLabelStyle,
      elevation: elevation ?? 8,
    );
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
}