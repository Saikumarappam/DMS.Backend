using System.Data;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using Helpers;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class ReportRepository : SqlRepositoryBase, IReportRepository
{
    public ReportRepository(IConfiguration configuration) : base(configuration) { }

    public Task<DataSet> GetDailyUploadsDataSetAsync(DateTime from, DateTime to) =>
        FetchSpDatasetAsync("sp_Report_DailyUploads", from, to);

    public Task<DataSet> GetMonthlyUploadsDataSetAsync(int year) =>
        FetchSpDatasetAsync("sp_Report_MonthlyUploads", year);

    public Task<DataSet> GetUserWiseDataSetAsync(DateTime? from, DateTime? to) =>
        FetchSpDatasetAsync("sp_Report_UserWise", DbValue(from), DbValue(to));

    public Task<DataSet> GetCategoryWiseDataSetAsync(DateTime? from, DateTime? to) =>
        FetchSpDatasetAsync("sp_Report_CategoryWise", DbValue(from), DbValue(to));

    public async Task<List<ReportItem>> GetDailyUploadsAsync(DateTime from, DateTime to)
    {
        var ds = await GetDailyUploadsDataSetAsync(from, to);
        return ds.Tables[0].Rows.Cast<DataRow>().Select(r => new ReportItem
        {
            Label = Convert.ToDateTime(r["UploadDay"]).ToString("yyyy-MM-dd"),
            DocumentCount = Convert.ToInt32(r["DocumentCount"]),
            TotalSize = Convert.ToInt64(r["TotalSize"])
        }).ToList();
    }

    public async Task<List<ReportItem>> GetMonthlyUploadsAsync(int year)
    {
        var ds = await GetMonthlyUploadsDataSetAsync(year);
        return ds.Tables[0].Rows.Cast<DataRow>().Select(r => new ReportItem
        {
            Label = r["UploadMonth"].ToString() ?? "",
            DocumentCount = Convert.ToInt32(r["DocumentCount"]),
            TotalSize = Convert.ToInt64(r["TotalSize"])
        }).ToList();
    }

    public async Task<List<ReportItem>> GetUserWiseAsync(DateTime? from, DateTime? to)
    {
        var ds = await GetUserWiseDataSetAsync(from, to);
        return ds.Tables[0].Rows.Cast<DataRow>().Select(r => new ReportItem
        {
            UserId = Convert.ToInt64(r["UserId"]),
            Label = $"{r["Name"]} ({r["BusinessName"]})",
            DocumentCount = Convert.ToInt32(r["DocumentCount"]),
            TotalSize = Convert.ToInt64(r["TotalSize"])
        }).ToList();
    }

    public async Task<List<ReportItem>> GetCategoryWiseAsync(DateTime? from, DateTime? to)
    {
        var ds = await GetCategoryWiseDataSetAsync(from, to);
        return ds.Tables[0].Rows.Cast<DataRow>().Select(r => new ReportItem
        {
            CategoryId = Convert.ToInt32(r["CategoryId"]),
            Label = r["CategoryName"].ToString() ?? "",
            DocumentCount = Convert.ToInt32(r["DocumentCount"]),
            TotalSize = Convert.ToInt64(r["TotalSize"])
        }).ToList();
    }
}
