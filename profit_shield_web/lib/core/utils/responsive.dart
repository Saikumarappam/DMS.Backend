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
