import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/logging_service.dart';
import '../../config/theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final double? toolbarHeight;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final IconThemeData? iconTheme;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleText,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.toolbarHeight,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.iconTheme,
    this.titleTextStyle,
    this.systemOverlayStyle,
  }) : assert(title == null || titleText == null, 'Cannot provide both title and titleText');

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building CustomAppBar with title: ${titleText ?? 'widget'}');
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultTitleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: screenWidth * 0.045,
      color: foregroundColor ?? AppTheme.onSurface,
    );

    final appBarTitle = title ?? (titleText != null
        ? Text(
            titleText!,
            style: titleTextStyle ?? defaultTitleStyle,
          )
        : null);

    return AppBar(
      title: appBarTitle,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor ?? AppTheme.surfaceColor,
      foregroundColor: foregroundColor ?? AppTheme.onSurface,
      elevation: elevation ?? 0,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      iconTheme: iconTheme,
      systemOverlayStyle: systemOverlayStyle,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    toolbarHeight ?? kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
}

// Helper widget for notification icon with badge
class NotificationIconWithBadge extends StatelessWidget {
  final int badgeCount;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double? iconSize;

  const NotificationIconWithBadge({
    super.key,
    required this.badgeCount,
    this.onPressed,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building NotificationIconWithBadge with count: $badgeCount');
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_none_outlined,
            size: iconSize ?? screenWidth * 0.06,
            color: iconColor ?? AppTheme.onSurface.withAlpha(138), // 0.54 * 255
          ),
          onPressed: onPressed,
        ),
        if (badgeCount > 0)
          Positioned(
            right: screenWidth * 0.02,
            top: screenWidth * 0.02,
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.005),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(
                minWidth: screenWidth * 0.04,
                minHeight: screenWidth * 0.04,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.025,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// Helper widget for logo title
class LogoTitle extends StatelessWidget {
  final String? text;
  final double? logoSize;
  final double? fontSize;
  final Color? textColor;

  const LogoTitle({
    super.key,
    this.text,
    this.logoSize,
    this.fontSize,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building LogoTitle with text: $text');
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: logoSize ?? screenWidth * 0.08,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.directions_boat,
            size: logoSize ?? screenWidth * 0.08,
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
        if (text != null)
          Text(
            text!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize ?? screenWidth * 0.045,
              color: textColor ?? AppTheme.onSurface,
            ),
          ),
      ],
    );
  }
}