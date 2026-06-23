using System.Data;
using DMS.Application.Common;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class CategoryRepository : SqlRepositoryBase, ICategoryRepository
{
    public CategoryRepository(IConfiguration configuration) : base(configuration) { }

    public Task<DataSet> GetAllDataSetAsync(bool includeInactive = false) =>
        FetchSpDatasetAsync("sp_Category_GetAll", includeInactive);

    public async Task<List<FileCategory>> GetAllAsync(bool includeInactive = false)
    {
        var ds = await GetAllDataSetAsync(includeInactive);
        return SpDataSetReader.MapAll<FileCategory>(ds);
    }

    public Task<DataSet> AddDataSetAsync(string name, string? description, long createdBy) =>
        FetchSpDatasetAsync("sp_Category_Add", name, DbValue(description), createdBy);

    public Task<DataSet> UpdateDataSetAsync(int id, string name, string? description, long modifiedBy) =>
        FetchSpDatasetAsync("sp_Category_Update", id, name, DbValue(description), modifiedBy);

    public Task<DataSet> DeleteDataSetAsync(int id, long modifiedBy) =>
        FetchSpDatasetAsync("sp_Category_Delete", id, modifiedBy);
}
