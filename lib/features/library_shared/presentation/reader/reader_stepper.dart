import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

/// 阅读器显示设置数值步进器：减按钮 / 可点输入当前值 / 加按钮。
///
/// 单击与长按均立即触发 [onChanged] 预览；长按松手或取消时仅提交一次
/// [onChangeEnd]。点击中间值弹出数字输入对话框，空值、非数字或越界时
/// 静默回退到当前值。
class ReaderStepper extends StatefulWidget {
  const ReaderStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.onChangeEnd,
    this.formatValue,
    this.displayScale = 1,
    this.fractionDigits = 0,
    this.enabled = true,
    this.keyPrefix,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double value)? formatValue;
  final double displayScale;
  final int fractionDigits;
  final bool enabled;
  final String? keyPrefix;

  @override
  State<ReaderStepper> createState() => _ReaderStepperState();
}

class _ReaderStepperState extends State<ReaderStepper> {
  static const double _epsilon = 1e-9;

  late double _value;
  Timer? _repeatTimer;
  bool _changedDuringLongPress = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(widget.min, widget.max).toDouble();
  }

  @override
  void didUpdateWidget(covariant ReaderStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _stopRepeatTimer(commitIfChanged: false);
    }
    if (_repeatTimer == null) {
      _value = widget.value.clamp(widget.min, widget.max).toDouble();
    }
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    super.dispose();
  }

  Key? _partKey(String suffix) {
    final prefix = widget.keyPrefix;
    return prefix == null ? null : ValueKey<String>('$prefix-$suffix');
  }

  int get _precision => math.max(
    _decimalPlaces(widget.step),
    math.max(_decimalPlaces(widget.min), widget.fractionDigits),
  );

  double _snapAndClamp(double raw) {
    final stepIndex = ((raw - widget.min) / widget.step).round();
    final stepped = (widget.min + stepIndex * widget.step)
        .clamp(widget.min, widget.max)
        .toDouble();
    if (_precision == 0) {
      return stepped.roundToDouble();
    }
    return double.parse(stepped.toStringAsFixed(_precision));
  }

  String _formatDisplayNumber(double value) {
    if (widget.formatValue != null) {
      return widget.formatValue!(value);
    }
    final scaled = value * widget.displayScale;
    return widget.fractionDigits == 0
        ? scaled.round().toString()
        : scaled.toStringAsFixed(widget.fractionDigits);
  }

  String _formatWithUnit(double value) =>
      '${_formatDisplayNumber(value)}${widget.unit}';

  bool get _canDecrease => widget.enabled && _value > widget.min + _epsilon;

  bool get _canIncrease => widget.enabled && _value < widget.max - _epsilon;

  bool _stepOnce(int direction, {required bool commit}) {
    if (!widget.enabled) {
      return false;
    }
    final next = _snapAndClamp(_value + direction * widget.step);
    if ((next - _value).abs() <= _epsilon) {
      return false;
    }
    setState(() => _value = next);
    widget.onChanged(next);
    if (commit) {
      widget.onChangeEnd?.call(next);
    }
    return true;
  }

  void _startLongPress(int direction) {
    if (!widget.enabled) {
      return;
    }
    _repeatTimer?.cancel();
    _changedDuringLongPress = false;
    if (_stepOnce(direction, commit: false)) {
      _changedDuringLongPress = true;
    }
    if ((direction < 0 && !_canDecrease) || (direction > 0 && !_canIncrease)) {
      return;
    }
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted || !widget.enabled) {
        timer.cancel();
        _repeatTimer = null;
        return;
      }
      if (_stepOnce(direction, commit: false)) {
        _changedDuringLongPress = true;
      }
      final hitBoundary =
          (direction < 0 && !_canDecrease) || (direction > 0 && !_canIncrease);
      if (hitBoundary) {
        timer.cancel();
        _repeatTimer = null;
      }
    });
  }

  void _stopRepeatTimer({required bool commitIfChanged}) {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    if (commitIfChanged && _changedDuringLongPress) {
      _changedDuringLongPress = false;
      widget.onChangeEnd?.call(_value);
    } else {
      _changedDuringLongPress = false;
    }
  }

  Future<void> _openDirectInputDialog() async {
    if (!widget.enabled) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    var draft = _formatDisplayNumber(_value);
    final minLabel = _formatWithUnit(widget.min);
    final maxLabel = _formatWithUnit(widget.max);
    final submitted = await showAppFormDialog<String>(
      context: context,
      title: widget.label,
      hasFields: true,
      content: _StepperNumericInput(
        inputKey: _partKey('input'),
        initialText: draft,
        unit: widget.unit,
        allowDecimal: widget.fractionDigits > 0 || widget.step < 1,
        helperText: l10n.readerStepperRangeHint(minLabel, maxLabel),
        onChanged: (value) => draft = value,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        AppDialogAction(
          key: _partKey('cancel'),
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          key: _partKey('confirm'),
          label: l10n.commonConfirm,
          onPressed: () => Navigator.of(context).pop(draft),
        ),
      ],
    );
    if (!mounted || submitted == null) {
      return;
    }
    final cleaned = _stripTrailingUnit(submitted.trim(), widget.unit);
    if (cleaned.isEmpty) {
      return;
    }
    final parsedDisplay = double.tryParse(cleaned);
    if (parsedDisplay == null ||
        parsedDisplay.isNaN ||
        parsedDisplay.isInfinite) {
      return;
    }
    final raw = parsedDisplay / widget.displayScale;
    if (raw < widget.min - _epsilon || raw > widget.max + _epsilon) {
      // 超出范围或非法输入静默回退到当前值。
      return;
    }
    final next = _snapAndClamp(raw);
    if ((next - _value).abs() <= _epsilon) {
      return;
    }
    setState(() => _value = next);
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  static String _stripTrailingUnit(String text, String unit) {
    if (unit.isNotEmpty && text.endsWith(unit)) {
      return text.substring(0, text.length - unit.length).trim();
    }
    return text;
  }

  static int _decimalPlaces(double number) {
    final fixed = number.toString();
    final dot = fixed.indexOf('.');
    if (dot < 0) {
      return 0;
    }
    return fixed.length - dot - 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelColor = widget.enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final displayText = _formatWithUnit(_value);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StepButton(
              buttonKey: _partKey('decrease'),
              icon: Icons.remove,
              semanticLabel: l10n.readerStepperDecrease(widget.label),
              enabled: _canDecrease,
              onTap: () => _stepOnce(-1, commit: true),
              onLongPressStart: () => _startLongPress(-1),
              onLongPressEnd: () => _stopRepeatTimer(commitIfChanged: true),
            ),
            Semantics(
              button: true,
              enabled: widget.enabled,
              label: l10n.readerStepperValueSemantics(
                widget.label,
                displayText,
              ),
              onTap: widget.enabled ? _openDirectInputDialog : null,
              child: ExcludeSemantics(
                child: InkWell(
                  key: _partKey('value'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.enabled ? _openDirectInputDialog : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 54,
                      minHeight: 48,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          displayText,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _StepButton(
              buttonKey: _partKey('increase'),
              icon: Icons.add,
              semanticLabel: l10n.readerStepperIncrease(widget.label),
              enabled: _canIncrease,
              onTap: () => _stepOnce(1, commit: true),
              onLongPressStart: () => _startLongPress(1),
              onLongPressEnd: () => _stopRepeatTimer(commitIfChanged: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.buttonKey,
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final Key? buttonKey;
  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.32);
    final fill = enabled
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerHigh.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          onLongPressStart: enabled ? (_) => onLongPressStart() : null,
          onLongPressEnd: enabled ? (_) => onLongPressEnd() : null,
          onLongPressCancel: enabled ? onLongPressEnd : null,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperNumericInput extends StatefulWidget {
  const _StepperNumericInput({
    required this.inputKey,
    required this.initialText,
    required this.unit,
    required this.allowDecimal,
    required this.helperText,
    required this.onChanged,
    required this.onSubmitted,
  });

  final Key? inputKey;
  final String initialText;
  final String unit;
  final bool allowDecimal;
  final String helperText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_StepperNumericInput> createState() => _StepperNumericInputState();
}

class _StepperNumericInputState extends State<_StepperNumericInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    // 随退场路由真正卸载时释放，避免确认关闭动画期间误销毁。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextInput(
      key: widget.inputKey,
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.allowDecimal,
      ),
      textInputAction: TextInputAction.done,
      suffixText: widget.unit.isEmpty ? null : widget.unit,
      helperText: widget.helperText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
