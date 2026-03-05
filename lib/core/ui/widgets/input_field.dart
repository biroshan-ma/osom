import 'package:flutter/material.dart';
import '../../ui/text_styles.dart';
import '../../ui/colors.dart';

typedef Validator = String? Function(String? value);

class InputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;
  final String? suffixSegment; // e.g. ".osom.global"
  final TextInputType keyboardType;
  final Validator? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const InputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.suffix,
    this.suffixSegment,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.focusNode,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    // If suffixSegment provided, build a segmented rounded input where the right segment
    // is a fixed non-editable label inside the rounded container.
    final base = Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Text input expands to fill remaining space
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              textAlignVertical: TextAlignVertical.center,
              cursorHeight: 20,
              keyboardType: keyboardType,
              validator: validator,
              focusNode: focusNode,
              textInputAction: textInputAction,
              style: AppTextStyles.input,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.input.copyWith(color: const Color(0xFFBFC9D4)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                // If suffixSegment is not provided allow the normal suffix widget
                suffixIcon: suffix != null && suffixSegment == null ? Padding(padding: EdgeInsets.zero, child: suffix) : null,
              ),
            ),
          ),
          // Optional suffix segment (non-editable)
          if (suffixSegment != null) ...[
            Container(
              width: 6,
              height: 36,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(suffixSegment!, style: const TextStyle(color: Color(0xFF7B8790), fontWeight: FontWeight.w600)),
            ),
            // If both suffix widget and suffixSegment provided, show the suffix widget after segment
            if (suffix != null) ...[
              const SizedBox(width: 6),
              suffix!,
            ],
          ]
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(height: 4),
        base,
      ],
    );
  }
}
