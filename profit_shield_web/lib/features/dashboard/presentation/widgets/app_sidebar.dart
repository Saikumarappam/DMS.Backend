import 'package:flutter/material.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class SidebarItem {
  const SidebarItem({
    required this.label,
    required this.icon,
    this.badge,
    this.route = '/dashboard',
  });

  final String label;
  final IconData icon;
  final int? badge;
  final String route;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedLabel,
    required this.userName,
    required this.userRole,
    required this.onSelect,
    required this.onLogout,
    required this.collapsed,
    this.width,
  });

  final List<SidebarItem> items;
  final String selectedLabel;
  final String userName;
  final String userRole;
  final ValueChanged<SidebarItem> onSelect;
  final VoidCallback onLogout;
  final bool collapsed;
  final double? width;

  static const double expandedWidth = 250;
  static const double collapsedWidth = 78;

  static const double _compactWidthThreshold = 120;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).width;
    final targetWidth = width ??
        (collapsed
            ? SidebarDims.collapsed(viewport)
            : SidebarDims.expanded(viewport));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: targetWidth,
      color: AppColors.navy,
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // During expand/collapse animation, width can be narrow while `collapsed`
          // is already false — use compact layout until there is enough space.
          final compact = collapsed;
          // final compact = collapsed || constraints.maxWidth < _compactWidthThreshold;

          return Column(
            children: [
              _SidebarHeader(collapsed: compact),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = item.label == selectedLabel;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SidebarNavTile(
                        item: item,
                        selected: selected,
                        collapsed: compact,
                        onTap: () => onSelect(item),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              _SidebarFooter(
                collapsed: compact,
                userName: userName,
                userRole: userRole,
                onLogout: onLogout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final SidebarItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  bool _hovering = false;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SidebarNavTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.collapsed || widget.item.label != oldWidget.item.label) {
      _removeTooltip();
    }
  }

  void _showTooltip() {
    if (!widget.collapsed || _entry != null) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.centerRight,
              followerAnchor: Alignment.centerLeft,
              offset: const Offset(10, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.navyLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.item.badge != null && widget.item.badge! > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.item.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
  }

  void _removeTooltip() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: widget.selected ? AppColors.navySidebarActive : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onTap,
        onHover: (hovering) {
          setState(() => _hovering = hovering);
          if (hovering) {
            _showTooltip();
          } else {
            _removeTooltip();
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 0 : 12,
            vertical: 12,
          ),
          child: widget.collapsed
              ? Center(
                  child: Badge(
                    isLabelVisible: widget.item.badge != null && widget.item.badge! > 0,
                    label: Text('${widget.item.badge}'),
                    backgroundColor: AppColors.warning,
                    child: Icon(
                      widget.item.icon,
                      color: _hovering || widget.selected ? Colors.white : Colors.white70,
                      size: AppScale.of(context).iconMd,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      color: widget.selected ? Colors.white : Colors.white70,
                      size: AppScale.of(context).iconMd,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.selected ? Colors.white : Colors.white70,
                          fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: AppScale.of(context).label,
                        ),
                      ),
                    ),
                    if (widget.item.badge != null && widget.item.badge! > 0)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.item.badge}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    if (!widget.collapsed) return tile;

    return CompositedTransformTarget(
      link: _link,
      child: tile,
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 8 : 12, 14, collapsed ? 8 : 12, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: collapsed ? 56 : 88,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 6 : 10,
          vertical: collapsed ? 8 : 10,
        ),
        decoration: BoxDecoration(
          // color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: collapsed
            ? Image.asset(
                AppAssets.logoMark,
                height: AppScale.of(context).isMobile ? 32 : 36,
                fit: BoxFit.contain,
              )
            : Image.asset(
                AppAssets.logoFull,
                height: AppScale.of(context).isMobile ? 42 : 50,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.collapsed,
    required this.userName,
    required this.userRole,
    required this.onLogout,
  });

  final bool collapsed;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 12,
        vertical: 12,
      ),
      child: Row(
        children: [
          // CircleAvatar(
          //   radius: collapsed ? 16 : 18,
          //   backgroundColor: AppColors.gold.withValues(alpha: 0.25),
          //   child: Text(
          //     userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          //     style: const TextStyle(
          //       color: AppColors.goldSoft,
          //       fontWeight: FontWeight.w700,
          //     ),
          //   ),
          // ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    userRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.expand_more, color: Colors.white70, size: 20),
              onSelected: (value) {
                if (value == 'logout') onLogout();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'logout', child: Text('Sign out')),
              ],
            ),
          ] else
            IconButton(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
              tooltip: '',
            ),
        ],
      ),
    );
  }
}
