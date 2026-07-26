using DMS.API.Helpers;
using DMS.Application.DTOs.Common;
using DMS.Application.Interfaces;

namespace DMS.Application.Services;

public class ReportService
{
    private readonly IReportRepository _reportRepo;
    private readonly CommonFunctions _commonFunctions;
    private readonly SpResponseBuilder _spResponse;

    public ReportService(IReportRepository reportRepo, CommonFunctions commonFunctions, SpResponseBuilder spResponse)
    {
        _reportRepo = reportRepo;
        _commonFunctions = commonFunctions;
        _spResponse = spResponse;
    }

    public async Task<Response> GetDailyAsync(DateTime from, DateTime to)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(from, to);
        try
        {
            var ds = await _reportRepo.GetDailyUploadsDataSetAsync(from, to);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("ReportService.cs", "GetDailyAsync", paramsJson, resp.message, 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("ReportService.cs", "GetDailyAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetMonthlyAsync(int year)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(year);
        try
        {
            var ds = await _reportRepo.GetMonthlyUploadsDataSetAsync(year);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("ReportService.cs", "GetMonthlyAsync", paramsJson, resp.message, 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("ReportService.cs", "GetMonthlyAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetUserWiseAsync(DateTime? from, DateTime? to)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(from, to);
        try
        {
            var ds = await _reportRepo.GetUserWiseDataSetAsync(from, to);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("ReportService.cs", "GetUserWiseAsync", paramsJson, resp.message, 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("ReportService.cs", "GetUserWiseAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetCategoryWiseAsync(DateTime? from, DateTime? to)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(from, to);
        try
        {
            var ds = await _reportRepo.GetCategoryWiseDataSetAsync(from, to);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("ReportService.cs", "GetCategoryWiseAsync", paramsJson, resp.message, 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("ReportService.cs", "GetCategoryWiseAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetAuditLogsAsync(DateTime? from, DateTime? to, long? userId, IAuditRepository auditRepo)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(from, to, userId);
        try
        {
            var ds = await auditRepo.GetLogsDataSetAsync(from, to, userId);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("ReportService.cs", "GetAuditLogsAsync", paramsJson, resp.message, 0, userId?.ToString() ?? "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("ReportService.cs", "GetAuditLogsAsync", paramsJson, ex.ToString(), 1, userId?.ToString() ?? "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    /// <summary>
    /// Dynamic admin dashboard data: all DataTables from sp_Dashboard_GetAdminData are automatically
    /// converted to Array0 (KPI), Array1 (category chart), Array2 (trend), Array3 (top clients), etc.
    /// Future-proof: any new DataTables added to the SP will automatically be returned as Array4, Array5, etc.
    /// </summary>
    public async Task<Response> GetAdminDashboardAsync()
    {
        var paramsJson = "{}";
        try
        {
            var ds = await _reportRepo.GetAdminDashboardDataSetAsync();
            var resp = await _spResponse.FromDataSetAsync(ds, "Dashboard data retrieved successfully");
            _commonFunctions.LogEvent("ReportService.cs", "GetAdminDashboardAsync", paramsJson, resp.message, 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("ReportService.cs", "GetAdminDashboardAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }
}
