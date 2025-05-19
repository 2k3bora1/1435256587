import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isRequired;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final Function(String)? onChanged;

  const FormTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isRequired = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        validator: validator ??
            (isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return '$label is required';
                    }
                    return null;
                  }
                : null),
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        enabled: enabled,
        onChanged: onChanged,
      ),
    );
  }
}

class FormNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isRequired;
  final String? Function(String?)? validator;
  final bool allowDecimal;
  final bool enabled;
  final Function(String)? onChanged;

  const FormNumberField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isRequired = false,
    this.validator,
    this.allowDecimal = false,
    this.enabled = true,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormTextField(
      controller: controller,
      label: label,
      hint: hint,
      prefixIcon: prefixIcon,
      isRequired: isRequired,
      validator: validator,
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        allowDecimal
            ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

class FormPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isRequired;
  final bool enabled;
  final Function(String)? onChanged;

  const FormPhoneField({
    Key? key,
    required this.controller,
    this.label = 'Phone Number',
    this.hint = 'Enter phone number',
    this.isRequired = false,
    this.enabled = true,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormTextField(
      controller: controller,
      label: label,
      hint: hint,
      prefixIcon: Icons.phone,
      isRequired: isRequired,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$label is required';
        }
        if (value != null && value.isNotEmpty && value.length < 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

class FormAadhaarField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isRequired;
  final bool enabled;
  final Function(String)? onChanged;

  const FormAadhaarField({
    Key? key,
    required this.controller,
    this.label = 'Aadhaar Number',
    this.hint = 'Enter 12-digit Aadhaar number',
    this.isRequired = false,
    this.enabled = true,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormTextField(
      controller: controller,
      label: label,
      hint: hint,
      prefixIcon: Icons.credit_card,
      isRequired: isRequired,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$label is required';
        }
        if (value != null && value.isNotEmpty && value.length != 12) {
          return 'Aadhaar number must be 12 digits';
        }
        return null;
      },
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

class FormDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isRequired;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final Function(DateTime)? onDateSelected;

  const FormDateField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.isRequired = false,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.onDateSelected,
  }) : super(key: key);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _parseDate(controller.text) ?? now;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(now.year + 10),
    );
    
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
      if (onDateSelected != null) {
        onDateSelected!(picked);
      }
    }
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parse(text);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint ?? 'Select date',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        readOnly: true,
        onTap: enabled ? () => _selectDate(context) : null,
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
        enabled: enabled,
      ),
    );
  }
}

class FormDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?) onChanged;
  final bool isRequired;
  final String? Function(T?)? validator;
  final bool enabled;

  const FormDropdownField({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isRequired = false,
    this.validator,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: validator ??
            (isRequired
                ? (value) {
                    if (value == null) {
                      return 'Please select $label';
                    }
                    return null;
                  }
                : null),
      ),
    );
  }
}