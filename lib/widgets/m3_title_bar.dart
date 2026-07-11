import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Material Design 3 自定义标题栏。
///
/// C++ 侧 WM_NCHITTEST 返回 HTCAPTION（拖拽 + 双击最大化）
/// 和 HTMAXBUTTON（Snap Layout）。Flutter 侧仅负责 UI 和按钮事件。
class M3TitleBar extends StatefulWidget {
  /// 标题栏左侧显示的应用标题文本。
  final String title;

  /// 标题栏高度，默认 40px（Windows 11 标准）。
  final double height;

  /// 标题栏背景色，null 时使用 [ColorScheme.surface]。
  final Color? backgroundColor;

  const M3TitleBar({
    super.key,
    this.title = 'NGS-KG+',
    this.height = 40,
    this.backgroundColor,
  });

  @override
  State<M3TitleBar> createState() => _M3TitleBarState();
}

class _M3TitleBarState extends State<M3TitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isFocused = true;
  bool _isHoveringDragArea = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initState();
  }

  Future<void> _initState() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = max);
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // ── WindowListener callbacks ──

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowFocus() {
    if (mounted) setState(() => _isFocused = true);
  }

  @override
  void onWindowBlur() {
    if (mounted) setState(() => _isFocused = false);
  }

  // ── Button handlers ──

  void _onMinimize() {
    debugPrint('[M3TitleBar] minimize');
    windowManager.minimize();
  }

  void _onMaximizeOrRestore() {
    debugPrint('[M3TitleBar] maximize/restore (current: ${_isMaximized ? "maximized" : "normal"})');
    if (_isMaximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  void _onClose() {
    debugPrint('[M3TitleBar] close');
    windowManager.close();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 标题栏背景色：聚焦时用 surface，失焦时略微变暗
    final bg = widget.backgroundColor ?? cs.surface;
    final effectiveBg = _isFocused ? bg : Color.lerp(bg, cs.outlineVariant, 0.08)!;
    final dragHoverBg = Color.lerp(effectiveBg, cs.surfaceContainerHighest, 0.35)!;

    return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: effectiveBg,
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // ── 拖拽区域（图标+标题+中间空白）──
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoveringDragArea = true),
                onExit: (_) => setState(() => _isHoveringDragArea = false),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    color: _isHoveringDragArea ? dragHoverBg : Colors.transparent,
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/images/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.music_note_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ],
                    ),
                ),
              ),
            ),

            // ── 右侧：MD3 风格窗口控制按钮 ──
            _CaptionButton(
              icon: Icons.horizontal_rule_rounded,
              tooltip: '最小化',
              onPressed: _onMinimize,
            ),
            _CaptionButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              tooltip: _isMaximized ? '还原' : '最大化',
              onPressed: _onMaximizeOrRestore,
              isMaximizeButton: true,
            ),
            _CaptionButton(
              icon: Icons.close_rounded,
              tooltip: '关闭',
              onPressed: _onClose,
              isCloseButton: true,
            ),
          ],
        ),
    );
  }
}

/// MD3 风格标题栏按钮（最小化 / 最大化 / 关闭）。
class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isCloseButton;
  final bool isMaximizeButton;

  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isCloseButton = false,
    this.isMaximizeButton = false,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double btnWidth = 46;

    Color? hoverBg;
    Color? hoverFg;

    if (widget.isCloseButton) {
      hoverBg = const Color(0xFFE81123);
      hoverFg = Colors.white;
    } else {
      hoverBg = cs.surfaceContainerHighest;
    }

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: btnWidth,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? hoverBg : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _isHovered && widget.isCloseButton
                ? hoverFg
                : cs.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
