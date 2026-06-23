using System.Data;

namespace DMS.Application.Common;

/// <summary>
/// Reads stored-procedure DataSet results using Apis-style patterns:
/// - Command SP: table 0 = ResultCode/ResultMessage, table 1+ = payload
/// - Query SP: inline ResultCode/Message in the same row as data
/// - Plain query: data rows only
/// </summary>
public static class SpDataSetReader
{
    public static bool HasRows(DataSet? dataSet) =>
        dataSet != null && dataSet.Tables.Count > 0 && dataSet.Tables[0].Rows.Count > 0;

    public static bool IsCommandResult(DataSet dataSet) =>
        HasRows(dataSet) &&
        dataSet.Tables[0].Columns.Contains("ResultCode") &&
        dataSet.Tables[0].Columns.Contains("ResultMessage") &&
        IsMetaOnlyRow(dataSet.Tables[0].Rows[0]);

    public static bool IsInlineQueryResult(DataSet dataSet)
    {
        if (!HasRows(dataSet) || dataSet.Tables.Count != 1)
            return false;

        var row = dataSet.Tables[0].Rows[0];
        if (!row.Table.Columns.Contains("ResultCode"))
            return false;

        if (row.Table.Columns.Contains("ResultMessage") && IsMetaOnlyRow(row))
            return false;

        return row.Table.Columns.Contains("Message") || !IsMetaOnlyRow(row);
    }

    public static bool IsMetaOnlyRow(DataRow row)
    {
        foreach (DataColumn column in row.Table.Columns)
        {
            if (!DataRowMapper.MetaColumns.Contains(column.ColumnName))
                return false;
        }

        return row.Table.Columns.Count > 0;
    }

    public static (int ResultCode, string ResultMessage, string? RecordId) ParseCommandResult(DataSet dataSet)
    {
        if (!IsCommandResult(dataSet))
            return (-99, "No response from database.", null);

        var row = dataSet.Tables[0].Rows[0];
        var recordId = row.Table.Columns.Contains("RecordId") && row["RecordId"] != DBNull.Value
            ? row["RecordId"].ToString()
            : null;

        return (
            Convert.ToInt32(row["ResultCode"]),
            row["ResultMessage"]?.ToString() ?? "",
            recordId);
    }

    public static bool TryParseInlineQueryResult(DataSet dataSet, out bool success, out string message)
    {
        success = false;
        message = string.Empty;

        if (!IsInlineQueryResult(dataSet))
            return false;

        var row = dataSet.Tables[0].Rows[0];
        var resultCode = Convert.ToInt32(row["ResultCode"]);
        message = DataRowMapper.GetString(row, "Message")
            ?? DataRowMapper.GetString(row, "ResultMessage")
            ?? string.Empty;

        if (IsMetaOnlyRow(row))
        {
            success = false;
            return true;
        }

        success = resultCode == 1;
        return true;
    }

    public static T? MapFirstOrDefault<T>(DataSet? dataSet) where T : class, new()
    {
        var row = GetFirstDataRow(dataSet);
        return row == null ? null : DataRowMapper.Map<T>(row);
    }

    public static T? MapFromTable<T>(DataSet? dataSet, int tableIndex) where T : class, new()
    {
        if (dataSet == null || dataSet.Tables.Count <= tableIndex || dataSet.Tables[tableIndex].Rows.Count == 0)
            return null;

        return DataRowMapper.Map<T>(dataSet.Tables[tableIndex].Rows[0]);
    }

    public static List<T> MapAll<T>(DataSet? dataSet, int tableIndex = 0) where T : class, new()
    {
        if (dataSet == null || dataSet.Tables.Count <= tableIndex)
            return [];

        return DataRowMapper.MapAll<T>(
            dataSet.Tables[tableIndex].Rows.Cast<DataRow>().Where(row => !IsMetaOnlyRow(row)));
    }

    public static DataRow? GetFirstDataRow(DataSet? dataSet)
    {
        if (!HasRows(dataSet))
            return null;

        var row = dataSet!.Tables[0].Rows[0];

        if (IsInlineQueryResult(dataSet))
        {
            if (!TryParseInlineQueryResult(dataSet, out var success, out _) || !success)
                return null;
        }
        else if (IsCommandResult(dataSet))
        {
            var (code, _, _) = ParseCommandResult(dataSet);
            if (code != 0)
                return null;

            if (dataSet.Tables.Count > 1 && dataSet.Tables[1].Rows.Count > 0)
                return dataSet.Tables[1].Rows[0];

            return null;
        }
        else if (IsMetaOnlyRow(row))
        {
            return null;
        }

        return row;
    }

    public static DataSet ToPayloadDataSet(DataSet dataSet)
    {
        if (IsCommandResult(dataSet) && dataSet.Tables.Count > 1)
        {
            var payload = new DataSet();
            for (var i = 1; i < dataSet.Tables.Count; i++)
                payload.Tables.Add(dataSet.Tables[i].Copy());

            return payload;
        }

        return dataSet;
    }
}
