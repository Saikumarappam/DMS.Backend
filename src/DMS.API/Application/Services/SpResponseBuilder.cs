using System.Collections.Specialized;
using System.Data;
using DMS.API.Helpers;
using DMS.Application.Common;
using DMS.Application.DTOs.Common;
using Newtonsoft.Json;

namespace DMS.Application.Services;

public class SpResponseBuilder
{
    private readonly CommonFunctions _commonFunctions;

    public SpResponseBuilder(CommonFunctions commonFunctions) => _commonFunctions = commonFunctions;

    public static bool IsCommandResult(DataSet ds) => SpDataSetReader.IsCommandResult(ds);

    public static (int ResultCode, string ResultMessage, string? RecordId) ParseCommandResult(DataSet ds) =>
        SpDataSetReader.ParseCommandResult(ds);

    public async Task<Response> FromCommandDataSetAsync(DataSet ds, string? successMessage = null)
    {
        if (!IsCommandResult(ds))
            return await FromDataSetAsync(ds);

        var (code, message, recordId) = ParseCommandResult(ds);
        var resp = FromSpResult(code, string.IsNullOrWhiteSpace(message)
            ? (code == 0 ? "Success" : "Operation failed.")
            : message);

        if (code == 0)
        {
            if (!string.IsNullOrWhiteSpace(successMessage))
                resp.message = successMessage;

            if (!string.IsNullOrWhiteSpace(recordId))
                resp.jsonstring = recordId;

            var payload = SpDataSetReader.ToPayloadDataSet(ds);
            if (payload.Tables.Count > 0 && payload.Tables.Cast<DataTable>().Any(t => t.Rows.Count > 0))
                resp.data = await _commonFunctions.DataSetToJson(payload, new ListDictionary());
        }

        return resp;
    }

    public async Task<Response> FromDataSetAsync(
        DataSet ds,
        string successMessage = "Success",
        string noDataMessage = "No Data Found")
    {
        var resp = new Response();

        if (SpDataSetReader.IsInlineQueryResult(ds))
        {
            if (!SpDataSetReader.TryParseInlineQueryResult(ds, out var success, out var spMessage))
            {
                resp.status = false;
                resp.statuscode = ResponseHelper.NotFound;
                resp.message = noDataMessage;
                return resp;
            }

            if (!success)
            {
                resp.status = false;
                resp.statuscode = ResponseHelper.NotFound;
                resp.message = string.IsNullOrWhiteSpace(spMessage) ? noDataMessage : spMessage;
                return resp;
            }

            resp.status = true;
            resp.statuscode = "0";
            resp.message = string.IsNullOrWhiteSpace(spMessage) ? successMessage : spMessage;
            resp.data = await _commonFunctions.DataSetToJson(ds, new ListDictionary());
            return resp;
        }

        if (ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
        {
            resp.status = true;
            resp.statuscode = "0";
            resp.message = successMessage;
            resp.data = await _commonFunctions.DataSetToJson(ds, new ListDictionary());
        }
        else
        {
            resp.status = false;
            resp.statuscode = ResponseHelper.NotFound;
            resp.message = noDataMessage;
        }

        return resp;
    }

    /// <summary>
    /// Login/refresh response: token + data.Array0 (user) + jsonstring (refresh session).
    /// </summary>
    public async Task<TokenResponse> BuildAuthTokenResponseAsync(DataSet userDs, string accessToken, string refreshToken, DateTime expiresAt, string message = "Login successful.")
    {
        var resp = await FromDataSetAsync(userDs, message, "User profile not found.");

        if (!resp.status)
        {
            return new TokenResponse
            {
                status = false,
                statuscode = "500",
                message = "Unable to load user profile after authentication."
            };
        }

        return new TokenResponse
        {
            status = true,
            statuscode = "0",
            message = message,
            data = resp.data,
            token = accessToken,
            refreshToken = refreshToken,
            expiresAt = expiresAt.ToUniversalTime()
        };
    }
    public TokenResponse FromSpResult(int resultCode, string message, string? token = null) =>
        new()
        {
            status = resultCode == 0,
            statuscode = ResponseHelper.MapStatusCode(resultCode, message),
            message = message,
            token = token ?? ""
        };
}
