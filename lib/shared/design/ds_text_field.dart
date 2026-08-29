/// macOS 风格输入框（文档 9.6 节 DSTextField）：圆角 8、focus 蓝边发光、错误态红边。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

class DSTextField extends StatefulWidget {
  const DSTextField({
    super.key,
    this.controller,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.autofocus = false,
    this.onChanged,
    this.inputFormatters,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  @override
  State<DSTextField> createState() => _DSTextFieldState();
}

class _DSTextFieldState extends State<DSTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted && _focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError
        ? tokens.dangerRed
        : _focused
            ? tokens.accentBlue
            : tokens.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(kRadiusTextField),
            border: Border.all(color: borderColor, width: _focused ? 2 : 1),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: tokens.accentBlue.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            inputFormatters: widget.inputFormatters,
            keyboardType: widget.keyboardType,
            style:
                TextStyle(fontSize: kFontSizeBody, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: kFontSizeBody,
                color: tokens.textSecondary.withValues(alpha: 0.6),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                fontSize: kFontSizeSmall,
                color: tokens.dangerRed,
              ),
            ),
          ),
      ],
    );
  }
}
