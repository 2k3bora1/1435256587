import 'package:flutter/material.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final String primaryButtonLabel;
  final String? secondaryButtonLabel;
  final VoidCallback? onPrimaryButtonPressed;
  final VoidCallback? onSecondaryButtonPressed;
  final Color primaryButtonColor;
  final Color? secondaryButtonColor;

  const CustomAlertDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.primaryButtonLabel,
    this.secondaryButtonLabel,
    this.onPrimaryButtonPressed,
    this.onSecondaryButtonPressed,
    this.primaryButtonColor = Colors.blue,
    this.secondaryButtonColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        if (secondaryButtonLabel != null)
          TextButton(
            onPressed: onSecondaryButtonPressed ?? () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: secondaryButtonColor,
            ),
            child: Text(secondaryButtonLabel!),
          ),
        TextButton(
          onPressed: onPrimaryButtonPressed ?? () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: primaryButtonColor,
          ),
          child: Text(primaryButtonLabel),
        ),
      ],
    );
  }
}