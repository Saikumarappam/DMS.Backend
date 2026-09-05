import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/dashboard_models.dart';

class TopClientsTable extends StatelessWidget {
  const TopClientsTable({super.key, required this.rows});

  final List<ClientPendingRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppScale.of(context).cardPadding + 4,
        AppScale.of(context).cardPadding + 4,
        AppScale.of(context).cardPadding + 4,
        8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Clients with Pending Tasks',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 44,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    headingTextStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Client Name')),
                      DataColumn(label: Text('Pending'), numeric: true),
                      DataColumn(label: Text('Docs'), numeric: true),
                      DataColumn(label: Text('Overdue'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      if (rows.isEmpty)
                        const DataRow(
                          cells: [
                            DataCell(Text('—')),
                            DataCell(Text('No clients found')),
                            DataCell(Text('0')),
                            DataCell(Text('0')),
                            DataCell(Text('0')),
                            DataCell(SizedBox.shrink()),
                          ],
                        )
                      else
                        for (final row in rows)
                          DataRow(
                            cells: [
                              DataCell(Text('${row.rank}')),
                              DataCell(
                                Text(
                                  row.clientName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${row.pendingTasks}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text('${row.documentsPending}')),
                              DataCell(
                                Text(
                                  '${row.overdueTasks}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'View',
                                  onPressed: () {},
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
