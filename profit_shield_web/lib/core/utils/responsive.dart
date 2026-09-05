import 'package:flutter/material.dart';

class Breakpoints {
  Breakpoints._();

  static const double mobile = 768;
  static const double tablet = 1024;
  static const double desktop = 1280;
  static const double wide = 1440;

  /// Content-area thresholds (after sidebar width is subtracted).
  static const double contentSingleRow = 1100;
  static const double contentComfortable = 900;
  static const double contentCompact = 640;
}

enum ScreenSize { mobile, tablet, desktop, wide }

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.wide) return ScreenSize.wide;
  if (width >= Breakpoints.desktop) return ScreenSize.desktop;
  if (width >= Breakpoints.mobile) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

/// Device-aware sizes for type, icons, and spacing.
class AppScale {
  AppScale._(this.width, this.height, this.size);

  factory AppScale.of(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return AppScale._(media.width, media.height, screenSizeOf(context));
  }

  final double width;
  final double height;
  final ScreenSize size;

  bool get isMobile => size == ScreenSize.mobile;
  bool get isTablet => size == ScreenSize.tablet;
  bool get isDesktop => size == ScreenSize.desktop || size == ScreenSize.wide;

  double get fontFactor => switch (size) {
        ScreenSize.mobile => 0.92,
        ScreenSize.tablet => 0.96,
        ScreenSize.desktop => 1.0,
        ScreenSize.wide => 1.02,
      };

  double sp(double desktopSize) => desktopSize * fontFactor;

  double get pageTitle => isMobile
      ? 20
      : isTablet
          ? 23
          : 26;
  double get sectionTitle => isMobile ? 14 : 16;
  double get body => isMobile ? 13 : 14;
  double get caption => isMobile ? 11 : 12.5;
  double get label => isMobile ? 12 : 13;

  double get iconSm => isMobile ? 16 : 18;
  double get iconMd => isMobile
      ? 18
      : isTablet
          ? 20
          : 22;
  double get iconLg => isMobile ? 22 : 24;

  double get pagePadding => isMobile
      ? 12
      : isTablet
          ? 16
          : 20;
  double get cardPadding => isMobile ? 12 : 16;
  double get gap => isMobile ? 8 : 12;
  double get topBarHeight => isMobile
      ? 56
      : isTablet
          ? 60
          : 64;
  double get buttonHeight => isMobile ? 42 : 48;
  double get radius => isMobile ? 10 : 12;

  VisualDensity get visualDensity =>
      isMobile ? VisualDensity.compact : VisualDensity.standard;
}

double previewDialogWidthOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  switch (screenSizeOf(context)) {
    case ScreenSize.mobile:
      return width * 0.9;
    case ScreenSize.tablet:
      return width * 0.8;
    case ScreenSize.desktop:
    case ScreenSize.wide:
      return width * 0.7;
  }
}

EdgeInsets previewDialogInsetOf(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final horizontal =
      ((size.width - previewDialogWidthOf(context)) / 2).clamp(8.0, 240.0);
  final vertical = (size.height * 0.05).clamp(12.0, 40.0);
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

double formDialogWidthOf(BuildContext context, {double max = 460}) {
  return (MediaQuery.sizeOf(context).width * 0.92).clamp(280.0, max);
}

/// Parent-relative search width so fields never overflow the content pane.
double searchFieldWidthOf(double parentWidth) {
  if (parentWidth <= 0) return 240;
  if (parentWidth < 520) return parentWidth;
  if (parentWidth < 900) return parentWidth.clamp(240.0, 380.0);
  return 320;
}

/// Stacks [start] above [end] when the parent is narrower than [breakpoint].
class AdaptiveSplit extends StatelessWidget {
  const AdaptiveSplit({
    super.key,
    required this.start,
    required this.end,
    this.breakpoint = 560,
    this.spacing = 10,
  });

  final Widget start;
  final Widget end;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              start,
              SizedBox(height: spacing),
              Align(alignment: Alignment.centerRight, child: end),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: start),
            SizedBox(width: spacing),
            end,
          ],
        );
      },
    );
  }
}

/// Layout mode driven by available content width (not full viewport).
enum ContentLayoutMode {
  /// Full single-row KPIs + charts/table row.
  spacious,

  /// Single rows with tighter spacing / horizontal scroll fallback.
  comfortable,

  /// Compact: allow scroll wrappers to avoid overflow.
  compact,
}

ContentLayoutMode contentLayoutMode(double contentWidth) {
  if (contentWidth >= Breakpoints.contentSingleRow) {
    return ContentLayoutMode.spacious;
  }
  if (contentWidth >= Breakpoints.contentComfortable) {
    return ContentLayoutMode.comfortable;
  }
  return ContentLayoutMode.compact;
}

/// Sidebar widths that scale safely with viewport.
class SidebarDims {
  SidebarDims._();

  static double collapsed(double viewportWidth) =>
      viewportWidth < Breakpoints.mobile ? 72 : 78;

  static double expanded(double viewportWidth) {
    if (viewportWidth < Breakpoints.tablet) return 240;
    if (viewportWidth < Breakpoints.desktop) {
      return (viewportWidth * 0.22).clamp(220.0, 250.0);
    }
    return 250;
  }
}
