using System.Data;
using System.Data.SqlClient;
using Helpers;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

/// <summary>
/// Base repository using SqlHelper stored-procedure pattern:
/// SqlHelper.ExecuteDatasetAsync(connectionString, spName, param1, param2, ...)
/// </summary>
public abstract class SqlRepositoryBase
{
    protected readonly string _constr;

    protected SqlRepositoryBase(IConfiguration configuration)
    {
        _constr = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not configured.");
    }

    protected static object DbValue(object? value) => value ?? DBNull.Value;

    protected static SqlParameter OutputParam(string name, SqlDbType type, int size = 0)
    {
        var parameter = new SqlParameter(name, type) { Direction = ParameterDirection.Output };
        if (size > 0)
            parameter.Size = size;
        return parameter;
    }

    protected async Task<DataSet> FetchSpDatasetAsync(string spName, params object[] parameterValues)
    {
        return await SqlHelper.ExecuteDatasetAsync(_constr, spName, parameterValues);
    }

    protected async Task<int> ExecuteSpNonQueryAsync(string spName, params object[] parameterValues)
    {
        return await SqlHelper.ExecuteNonQueryAsync(_constr, spName, parameterValues);
    }

    protected static bool HasRows(DataSet dataSet) =>
        dataSet.Tables.Count > 0 && dataSet.Tables[0].Rows.Count > 0;
}
