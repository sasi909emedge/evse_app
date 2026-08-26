import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

Widget sectionHeader(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.45),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

Widget infoRow(
  String label,
  String value, {
  required Color surface,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
}) =>
    Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value.isEmpty ? "--" : value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: value.isEmpty ? textSecondary : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

Widget boolStatusChipRow(
  String label,
  bool value, {
  required Color surface,
  required Color border,
  required Color textSecondary,
  String onLabel = "Available",
  String offLabel = "Unavailable",
}) =>
    Container(
      color: surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 13, color: textSecondary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: value
                        ? AppColors.success.withOpacity(0.12)
                        : AppColors.error.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value ? onLabel : offLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: value ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),
        ],
      ),
    );

Widget dropRow(
  String label,
  String value, {
  required Color surface,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
}) =>
    Container(
      color: surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text(label,
                    style: TextStyle(fontSize: 13, color: textSecondary))),
            Expanded(
                flex: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                        child: Text(value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary))),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: textSecondary),
                  ],
                )),
          ]),
        ),
        Divider(height: 1, color: border),
      ]),
    );

Widget editableField(
  String label,
  TextEditingController ctrl, {
  required bool isDark,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  required VoidCallback onDirty,
  TextInputType keyboard = TextInputType.text,
  bool obscure = false,
  bool readOnly = false,
  TextInputAction action = TextInputAction.next,
}) {
  final key = GlobalObjectKey(ctrl);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          onChanged: (_) => onDirty(),
          keyboardType: keyboard,
          obscureText: obscure,
          readOnly: readOnly,
          textInputAction: action,
          style: TextStyle(
              fontSize: 14, color: readOnly ? textSecondary : textPrimary),
          scrollPadding: const EdgeInsets.only(bottom: 400),
          onTap: readOnly
              ? null
              : () {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (key.currentContext != null) {
                      Scrollable.ensureVisible(key.currentContext!,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: 0.3);
                    }
                  });
                },
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: readOnly
                ? (isDark ? AppColors.borderDark : AppColors.borderStrong)
                : (isDark ? const Color(0xFF18232E) : Colors.white),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: readOnly ? border : AppColors.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border, width: 1),
            ),
            suffixIcon: readOnly
                ? Icon(Icons.lock_outline_rounded,
                    size: 16, color: textSecondary)
                : null,
          ),
        ),
      ],
    ),
  );
}

Widget rawField(
  String label,
  TextEditingController ctrl, {
  required bool isDark,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  TextInputType keyboard = TextInputType.text,
  bool readOnly = false,
  ValueChanged<String>? onChanged,
}) {
  final key = GlobalObjectKey(ctrl);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          readOnly: readOnly,
          onChanged: onChanged,
          style: TextStyle(
              fontSize: 14, color: readOnly ? textSecondary : textPrimary),
          scrollPadding: const EdgeInsets.only(bottom: 400),
          onTap: readOnly
              ? null
              : () {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (key.currentContext != null) {
                      Scrollable.ensureVisible(key.currentContext!,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: 0.3);
                    }
                  });
                },
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: readOnly
                ? (isDark ? AppColors.borderDark : AppColors.borderStrong)
                : (isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: readOnly ? border : AppColors.primary, width: 1.5)),
            suffixIcon: readOnly
                ? Icon(Icons.lock_outline, size: 16, color: textSecondary)
                : null,
          ),
        ),
      ],
    ),
  );
}

Widget intField(
  String label,
  int value,
  ValueChanged<int> onChanged, {
  required bool isDark,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  bool readOnly = false,
}) {
  final ctrl = TextEditingController(text: value.toString());
  return rawField(
    label,
    ctrl,
    isDark: isDark,
    border: border,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    readOnly: readOnly,
    keyboard: TextInputType.number,
    onChanged: (v) {
      final n = int.tryParse(v);
      if (n != null) onChanged(n);
    },
  );
}

Widget dropEdit<T>(
  String label,
  T value,
  Map<T, String> opts,
  ValueChanged<T> onChanged, {
  required bool isDark,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  required Color surface,
  required VoidCallback onDirty,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18232E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: surface,
              icon:
                  Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary),
              items: opts.entries
                  .map((e) =>
                      DropdownMenuItem<T>(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(v);
                onDirty();
              },
            ),
          ),
        ),
      ]),
    );

Widget toggleRow(
  String label,
  bool value,
  ValueChanged<bool> onChanged, {
  required bool editMode,
  required Color border,
  required Color textSecondary,
  required VoidCallback onDirty,
}) =>
    Container(
      color: Colors.transparent,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13, color: textSecondary))),
            Switch(
              value: value,
              onChanged: editMode
                  ? (v) {
                      onChanged(v);
                      onDirty();
                    }
                  : null,
              activeColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(value ? "ON" : "OFF",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value ? AppColors.success : textSecondary)),
          ]),
        ),
        Divider(height: 1, color: border),
      ]),
    );

Widget checkEditRow(
  String label,
  bool value,
  ValueChanged<bool> onChanged, {
  required bool editMode,
  required Color textSecondary,
  required VoidCallback onDirty,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: textSecondary))),
        Checkbox(
          value: value,
          onChanged: editMode
              ? (bool? v) {
                  if (v == null) return;
                  onChanged(v);
                  onDirty();
                }
              : null,
          activeColor: AppColors.primary,
        ),
      ]),
    );

Widget actionButton(
        String label, IconData icon, Color color, VoidCallback fn) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: fn,
      ),
    );

Widget miniIntField(
  String label,
  int value,
  ValueChanged<int> onChanged, {
  required bool isDark,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  required Color surface,
  bool readOnly = false,
}) {
  final ctrl = TextEditingController(text: value.toString());
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: textSecondary))),
      Expanded(
        child: SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            readOnly: readOnly,
            scrollPadding: const EdgeInsets.only(bottom: 400),
            style: TextStyle(
                fontSize: 12, color: readOnly ? textSecondary : textPrimary),
            onChanged: readOnly
                ? null
                : (v) {
                    final n = int.tryParse(v);
                    if (n != null) onChanged(n);
                  },
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: readOnly
                  ? (isDark ? AppColors.borderDark : AppColors.borderStrong)
                  : surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: readOnly ? border : AppColors.primary,
                      width: 1.5)),
              suffixIcon: readOnly
                  ? Icon(Icons.lock_outline, size: 14, color: textSecondary)
                  : null,
            ),
          ),
        ),
      ),
    ]),
  );
}

Widget miniFloatField(
  String label,
  TextEditingController ctrl, {
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  required Color surface,
  required VoidCallback onDirty,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: textSecondary))),
        Expanded(
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: ctrl,
              onChanged: (_) => onDirty(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              scrollPadding: const EdgeInsets.only(bottom: 400),
              style: TextStyle(fontSize: 12, color: textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
        ),
      ]),
    );

Widget miniDropEdit<T>(
  String label,
  T value,
  Map<T, String> opts,
  ValueChanged<T> onChanged, {
  required bool isDark,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  required Color surface,
  bool readOnly = false,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: textSecondary))),
        Expanded(
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: readOnly
                  ? (isDark ? AppColors.borderDark : AppColors.borderStrong)
                  : surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                dropdownColor: surface,
                style: TextStyle(
                    fontSize: 12,
                    color: readOnly ? textSecondary : textPrimary),
                items: opts.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style:
                                TextStyle(fontSize: 12, color: textPrimary))))
                    .toList(),
                onChanged: readOnly
                    ? null
                    : (v) {
                        if (v != null) onChanged(v);
                      },
              ),
            ),
          ),
        ),
      ]),
    );
