using System.Collections.Specialized;
using System.Data;
using System.Text.Json.Nodes;
using Helpers;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DMS.API.Helpers;

public class CommonFunctions
{
    private readonly IConfiguration _config;
    private readonly string _conn;

    public CommonFunctions(IConfiguration config)
    {
        _config = config;
        _conn = config.GetConnectionString("DefaultConnection") ?? "";
    }

    public Task<ListDictionary> DataSetToJson(DataSet ds, ListDictionary data)
    {
        for (var i = 0; i < ds.Tables.Count; i++)
        {
            var dt = ds.Tables[i];
            var json = dt.Rows.Count == 0 ? TableHeadersToJson(dt) : TableToJson(dt);
            data.Add("Array" + i, JsonArray.Parse(json));
        }

        return Task.FromResult(data);
    }

    public string TableHeadersToJson(DataTable dt)
    {
        var headers = new List<Dictionary<string, object?>>();
        var headerDict = new Dictionary<string, object?>();
        foreach (DataColumn column in dt.Columns)
            headerDict[column.ColumnName] = null;

        headers.Add(headerDict);
        return JsonConvert.SerializeObject(headers);
    }

    public string TableToJson(DataTable dt) =>
        JsonConvert.SerializeObject(dt, Formatting.Indented);

    public Task<string> StringParamsToJson(params object[] values)
    {
        var obj = new JObject();
        for (var i = 0; i < values.Length; i++)
            obj.Add("param_" + (i + 1), values[i]?.ToString());

        return Task.FromResult(obj.ToString());
    }

    public void LogEvent(string eventSource, string eventProcedure, string param, string eventDescription, int isError, string uniqueId)
    {
        _ = LogEventAsync(eventSource, eventProcedure, param, eventDescription, isError, uniqueId);
    }

    public async Task LogEventAsync(string eventSource, string eventProcedure, string param, string eventDescription, int isError, string uniqueId)
    {
        try
        {
            if (_config.GetSection("verbose").Value == "true")
            {
                await SqlHelper.ExecuteNonQueryAsync(_conn, "INSEventDetails",
                    "API/" + eventSource, eventProcedure, param, eventDescription, isError, uniqueId);
            }

            if (isError == 1)
            {
                await SqlHelper.ExecuteNonQueryAsync(_conn, "INSEventDetails",
                    "API/" + eventSource, eventProcedure, param, eventDescription, isError, uniqueId);
            }
        }
        catch (Exception ex)
        {
            WriteFallbackLog(eventSource, eventProcedure, param, eventDescription, isError, uniqueId, ex);
        }
    }

    private static void WriteFallbackLog(string eventSource, string eventProcedure, string param, string eventDescription, int isError, string uniqueId, Exception exception)
    {
        try
        {
            var logDir = Path.Combine(AppContext.BaseDirectory, "logs");
            Directory.CreateDirectory(logDir);
            var logFile = Path.Combine(logDir, "fallback-log.txt");
            var line =
                $"[{DateTime.UtcNow:O}] Source={eventSource} Procedure={eventProcedure} IsError={isError} UniqueId={uniqueId} " +
                $"Param={param} Event={eventDescription} LoggingException={exception}\n";
            File.AppendAllText(logFile, line);
        }
        catch
        {
            // Last-resort logging must never break API flow.
        }
    }
}
