using System.Data;
using DMS.Application.Common;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class DocumentRepository : SqlRepositoryBase, IDocumentRepository
{
    public DocumentRepository(IConfiguration configuration) : base(configuration) { }

    public Task<DataSet> UploadDataSetAsync(
        long clientId, int categoryId, string categoryName, string fileName, string originalName,
        string filePath, string extension, long fileSize, string source, long createdBy) =>
        FetchSpDatasetAsync("sp_Document_Upload",
            clientId, categoryId, categoryName, fileName, originalName, filePath, extension, fileSize, source, createdBy);

    public Task<DataSet> GetHistoryDataSetAsync(long? clientId, int? categoryId, DateTime? from, DateTime? to, string? search) =>
        FetchSpDatasetAsync("sp_Document_GetHistory",
            DbValue(clientId), DbValue(categoryId), DbValue(from), DbValue(to), DbValue(search));

    public Task<DataSet> GetByIdDataSetAsync(long fileId) =>
        FetchSpDatasetAsync("sp_Document_GetById", fileId);

    public Task<DataSet> GetDashboardStatsDataSetAsync(long clientId) =>
        FetchSpDatasetAsync("sp_Document_GetDashboardStats", clientId);

    public async Task<FileDetail?> GetByIdAsync(long fileId)
    {
        var ds = await GetByIdDataSetAsync(fileId);
        return SpDataSetReader.MapFirstOrDefault<FileDetail>(ds);
    }
}
