using System.Data;
using System.Reflection;

namespace DMS.Application.Common;

/// <summary>
/// Maps DataRow columns to entity properties by name (case-insensitive).
/// New SP columns map automatically when a matching property exists on the entity.
/// </summary>
public static class DataRowMapper
{
    public static readonly HashSet<string> MetaColumns = new(StringComparer.OrdinalIgnoreCase)
    {
        "ResultCode", "ResultMessage", "Message", "RecordId"
    };

    public static T? Map<T>(DataRow row) where T : class, new()
    {
        if (row == null)
            return null;

        var entity = new T();
        var mappedColumns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var property in typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance))
        {
            if (!property.CanWrite || string.Equals(property.Name, "AdditionalFields", StringComparison.Ordinal))
                continue;

            var column = FindColumn(row.Table, property.Name);
            if (column == null || MetaColumns.Contains(column.ColumnName))
                continue;

            if (row[column] == DBNull.Value)
                continue;

            if (!TrySetProperty(entity, property, row[column]))
                continue;

            mappedColumns.Add(column.ColumnName);
        }

        var additionalFieldsProperty = typeof(T).GetProperty("AdditionalFields");
        if (additionalFieldsProperty?.CanWrite == true &&
            additionalFieldsProperty.PropertyType == typeof(Dictionary<string, object?>))
        {
            var extras = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (DataColumn column in row.Table.Columns)
            {
                if (MetaColumns.Contains(column.ColumnName) || mappedColumns.Contains(column.ColumnName))
                    continue;

                extras[column.ColumnName] = row[column] == DBNull.Value ? null : row[column];
            }

            additionalFieldsProperty.SetValue(entity, extras);
        }

        return entity;
    }

    public static List<T> MapAll<T>(IEnumerable<DataRow> rows) where T : class, new() =>
        rows.Select(Map<T>).Where(x => x != null).Cast<T>().ToList();

    public static string? GetString(DataRow row, string columnName)
    {
        var column = FindColumn(row.Table, columnName);
        if (column == null || row[column] == DBNull.Value)
            return null;

        return row[column]?.ToString();
    }

    public static TValue? GetValue<TValue>(DataRow row, string columnName)
    {
        var column = FindColumn(row.Table, columnName);
        if (column == null || row[column] == DBNull.Value)
            return default;

        var converted = ConvertValue(row[column], typeof(TValue));
        return converted is TValue value ? value : default;
    }

    private static DataColumn? FindColumn(DataTable table, string propertyName) =>
        table.Columns.Cast<DataColumn>()
            .FirstOrDefault(c => string.Equals(c.ColumnName, propertyName, StringComparison.OrdinalIgnoreCase));

    private static bool TrySetProperty(object entity, PropertyInfo property, object value)
    {
        try
        {
            var converted = ConvertValue(value, property.PropertyType);
            property.SetValue(entity, converted);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static object? ConvertValue(object value, Type targetType)
    {
        if (value == DBNull.Value)
            return null;

        var underlyingType = Nullable.GetUnderlyingType(targetType) ?? targetType;

        if (underlyingType == typeof(string))
            return value.ToString();

        if (underlyingType == typeof(bool))
        {
            if (value is bool boolValue)
                return boolValue;

            if (value is string stringValue && bool.TryParse(stringValue, out var parsedBool))
                return parsedBool;

            return Convert.ToInt32(value) != 0;
        }

        if (underlyingType == typeof(int))
            return Convert.ToInt32(value);

        if (underlyingType == typeof(long))
            return Convert.ToInt64(value);

        if (underlyingType == typeof(decimal))
            return Convert.ToDecimal(value);

        if (underlyingType == typeof(DateTime))
            return Convert.ToDateTime(value);

        if (underlyingType == typeof(Guid))
            return value is Guid guidValue ? guidValue : Guid.Parse(value.ToString()!);

        if (underlyingType.IsEnum)
            return Enum.ToObject(underlyingType, value);

        return Convert.ChangeType(value, underlyingType);
    }
}
