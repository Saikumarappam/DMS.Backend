using DMS.API.Helpers;
using DMS.Application.DTOs.Categories;
using DMS.Application.DTOs.Common;
using DMS.Application.Interfaces;

namespace DMS.Application.Services;

public class CategoryService
{
    private readonly ICategoryRepository _categoryRepo;
    private readonly CommonFunctions _commonFunctions;
    private readonly SpResponseBuilder _spResponse;

    public CategoryService(ICategoryRepository categoryRepo, CommonFunctions commonFunctions, SpResponseBuilder spResponse)
    {
        _categoryRepo = categoryRepo;
        _commonFunctions = commonFunctions;
        _spResponse = spResponse;
    }

    public async Task<Response> GetAllAsync(bool includeInactive = false)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(includeInactive);
        try
        {
            var ds = await _categoryRepo.GetAllDataSetAsync(includeInactive);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("CategoryService.cs", "GetAllAsync", paramsJson, resp.message, 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("CategoryService.cs", "GetAllAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> AddAsync(CreateCategoryRequest request, long userId)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(request.CategoryName, userId);
        try
        {
            var ds = await _categoryRepo.AddDataSetAsync(request.CategoryName, request.Description, userId);
            var resp = await _spResponse.FromCommandDataSetAsync(ds);
            _commonFunctions.LogEvent("CategoryService.cs", "AddAsync", paramsJson, resp.message, resp.status ? 0 : 1, userId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("CategoryService.cs", "AddAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> UpdateAsync(int id, UpdateCategoryRequest request, long userId)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(id, userId);
        try
        {
            var ds = await _categoryRepo.UpdateDataSetAsync(id, request.CategoryName, request.Description, userId);
            var resp = await _spResponse.FromCommandDataSetAsync(ds);
            _commonFunctions.LogEvent("CategoryService.cs", "UpdateAsync", paramsJson, resp.message, resp.status ? 0 : 1, userId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("CategoryService.cs", "UpdateAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> DeleteAsync(int id, long userId)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(id, userId);
        try
        {
            var ds = await _categoryRepo.DeleteDataSetAsync(id, userId);
            var resp = await _spResponse.FromCommandDataSetAsync(ds);
            _commonFunctions.LogEvent("CategoryService.cs", "DeleteAsync", paramsJson, resp.message, resp.status ? 0 : 1, userId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("CategoryService.cs", "DeleteAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }
}
