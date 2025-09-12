import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/logging_service.dart';

class CustomTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double? borderRadius;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final FocusNode? focusNode;
  final String? errorText;
  final bool showCounter;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.inputFormatters,
    this.contentPadding,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.borderRadius,
    this.labelStyle,
    this.hintStyle,
    this.textStyle,
    this.focusNode,
    this.errorText,
    this.showCounter = false,
  });

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building CustomTextField with label: $label');
    final defaultContentPadding = EdgeInsets.symmetric(
      horizontal: AppTheme.responsivePadding(context),
      vertical: AppTheme.spacing12,
    );

    final defaultLabelStyle = AppTheme.labelMedium(context).copyWith(
      fontWeight: FontWeight.bold,
      color: AppTheme.onSurface,
    );

    final defaultHintStyle = AppTheme.bodyMedium(context).copyWith(
      color: AppTheme.subtitleColor,
    );

    final defaultTextStyle = AppTheme.bodyMedium(context).copyWith(
      color: AppTheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: labelStyle ?? defaultLabelStyle,
          ),
          SizedBox(height: AppTheme.spacing8),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          focusNode: focusNode,
          inputFormatters: inputFormatters,
          style: textStyle ?? defaultTextStyle,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: hintStyle ?? defaultHintStyle,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.subtitleColor)
                : null,
            suffixIcon: suffixIcon,
            contentPadding: contentPadding ?? defaultContentPadding,
            filled: true,
            fillColor: fillColor ?? (readOnly ? AppTheme.greyShade200 : AppTheme.greyShade50),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: borderColor ?? AppTheme.greyShade300,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: borderColor ?? AppTheme.greyShade300,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: focusedBorderColor ?? AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            errorText: errorText,
            counterText: showCounter ? null : '',
          ),
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
        ),
      ],
    );
  }
}