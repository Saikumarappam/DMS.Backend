import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';



import '../../core/theme/app_colors.dart';



class ClientBottomNav extends StatelessWidget {

  const ClientBottomNav({

    super.key,

    required this.currentIndex,

    required this.onTap,

  });



  final int currentIndex;

  final ValueChanged<int> onTap;



  static const _items = [

    _NavItem(Icons.grid_view_rounded, 'Dashboard', '/dashboard'),

    _NavItem(Icons.history_rounded, 'History', '/history'),

    _NavItem(Icons.person_outline_rounded, 'Profile', '/profile'),

  ];



  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),

        boxShadow: [

          BoxShadow(

            color: AppColors.primary.withValues(alpha: 0.08),

            blurRadius: 20,

            offset: const Offset(0, -4),

          ),

        ],

      ),

      child: SafeArea(

        top: false,

        child: Padding(

          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),

          child: Row(

            mainAxisAlignment: MainAxisAlignment.spaceAround,

            children: List.generate(_items.length, (index) {

              final item = _items[index];

              final selected = currentIndex == index;

              return _NavButton(

                item: item,

                selected: selected,

                onTap: () {

                  onTap(index);

                  context.go(item.route);

                },

              );

            }),

          ),

        ),

      ),

    );

  }

}



class _NavItem {

  const _NavItem(this.icon, this.label, this.route);

  final IconData icon;

  final String label;

  final String route;

}



class _NavButton extends StatefulWidget {

  const _NavButton({

    required this.item,

    required this.selected,

    required this.onTap,

  });



  final _NavItem item;

  final bool selected;

  final VoidCallback onTap;



  @override

  State<_NavButton> createState() => _NavButtonState();

}



class _NavButtonState extends State<_NavButton> with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  late final Animation<double> _scale;



  @override

  void initState() {

    super.initState();

    _controller = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 200),

    );

    _scale = Tween<double>(begin: 1, end: 0.88).animate(

      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),

    );

    if (widget.selected) _controller.value = 0;

  }



  @override

  void didUpdateWidget(covariant _NavButton oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.selected && !oldWidget.selected) {

      _controller.forward().then((_) => _controller.reverse());

    }

  }



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final color = widget.selected ? AppColors.primary : AppColors.textMuted;



    return GestureDetector(

      onTapDown: (_) => _controller.forward(),

      onTapUp: (_) {

        _controller.reverse();

        widget.onTap();

      },

      onTapCancel: () => _controller.reverse(),

      child: ScaleTransition(

        scale: _scale,

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 250),

          curve: Curves.easeOut,

          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),

          decoration: BoxDecoration(

            color: widget.selected ? AppColors.sky.withValues(alpha: 0.6) : Colors.transparent,

            borderRadius: BorderRadius.circular(14),

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              AnimatedContainer(

                duration: const Duration(milliseconds: 250),

                padding: const EdgeInsets.all(6),

                decoration: widget.selected

                    ? BoxDecoration(

                        gradient: AppColors.icon3DGradient,

                        borderRadius: BorderRadius.circular(10),

                        boxShadow: [

                          BoxShadow(

                            color: AppColors.primary.withValues(alpha: 0.2),

                            blurRadius: 6,

                            offset: const Offset(0, 3),

                          ),

                        ],

                      )

                    : null,

                child: Icon(widget.item.icon, color: color, size: 22),

              ),

              const SizedBox(height: 4),

              Text(

                widget.item.label,

                style: TextStyle(

                  fontSize: 11,

                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,

                  color: color,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



int bottomNavIndexForLocation(String location) {

  if (location.startsWith('/history')) return 1;

  if (location.startsWith('/profile')) return 2;

  return 0;

}


