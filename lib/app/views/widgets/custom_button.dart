import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum CustomButtonType {
  elevated,
  outlined,
  text,
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderRadius;
  final TextStyle? textStyle;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CustomButtonType.elevated,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius = 12.0,
    this.textStyle,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultPadding = EdgeInsets.symmetric(
      horizontal: screenWidth * 0.08,
      vertical: screenWidth * 0.03,
    );

    final buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null && !isLoading) ...[
          leadingIcon!,
          SizedBox(width: screenWidth * 0.02),
        ],
        if (isLoading) ...[
          SizedBox(
            width: screenWidth * 0.05,
            height: screenWidth * 0.05,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? (type == CustomButtonType.elevated ? AppTheme.whiteColor : Theme.of(context).primaryColor),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
        ],
        Flexible(
          child: Text(
            isLoading ? 'Loading...' : text,
            style: textStyle ?? TextStyle(
              fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody2, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeH6),
              fontWeight: FontWeight.w500,
              color: foregroundColor ?? (type == CustomButtonType.elevated ? AppTheme.whiteColor : Theme.of(context).primaryColor),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          SizedBox(width: screenWidth * 0.02),
          trailingIcon!,
        ],
      ],
    );

    final buttonWidget = switch (type) {
      CustomButtonType.elevated => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor ?? AppTheme.whiteColor,
            padding: padding ?? defaultPadding,
            minimumSize: isFullWidth ? const Size(double.infinity, 0) : Size(width ?? 0, height ?? 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            elevation: 2,
          ),
          child: buttonContent,
        ),
      CustomButtonType.outlined => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? Theme.of(context).primaryColor,
            side: BorderSide(color: borderColor ?? Theme.of(context).primaryColor),
            padding: padding ?? defaultPadding,
            minimumSize: isFullWidth ? const Size(double.infinity, 0) : Size(width ?? 0, height ?? 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: buttonContent,
        ),
      CustomButtonType.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor ?? Theme.of(context).primaryColor,
            padding: padding ?? defaultPadding,
            minimumSize: isFullWidth ? const Size(double.infinity, 0) : Size(width ?? 0, height ?? 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: buttonContent,
        ),
    };

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}