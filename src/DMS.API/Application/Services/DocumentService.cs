using System.Data;
using DMS.API.Helpers;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Documents;
using DMS.Application.Interfaces;

namespace DMS.Application.Services;

public class DocumentService
{
    private readonly IDocumentRepository _documentRepo;
    private readonly IFileStorageService _fileStorage;
    private readonly IUserRepository _userRepo;
    private readonly ICategoryRepository _categoryRepo;
    private readonly CommonFunctions _commonFunctions;
    private readonly SpResponseBuilder _spResponse;

    public DocumentService(
        IDocumentRepository documentRepo,
        IFileStorageService fileStorage,
        IUserRepository userRepo,
        ICategoryRepository categoryRepo,
        CommonFunctions commonFunctions,
        SpResponseBuilder spResponse)
    {
        _documentRepo = documentRepo;
        _fileStorage = fileStorage;
        _userRepo = userRepo;
        _categoryRepo = categoryRepo;
        _commonFunctions = commonFunctions;
        _spResponse = spResponse;
    }

    public async Task<Response> UploadAsync(
        long clientId, int categoryId, string source, Stream fileStream, string originalName)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(clientId, categoryId, originalName);
        try
        {
            var extension = Path.GetExtension(originalName).ToLowerInvariant();
            if (!_fileStorage.IsAllowedExtension(extension))
            {
                var resp = ResponseHelper.Validation("File type not allowed. Supported: JPG, JPEG, PNG, PDF.");
                _commonFunctions.LogEvent("DocumentService.cs", "UploadAsync", paramsJson, resp.message, 0, clientId.ToString());
                return resp;
            }

            if (!_fileStorage.IsAllowedSize(fileStream.Length))
            {
                var resp = ResponseHelper.Validation("File size must be between 500KB and 5MB.");
                _commonFunctions.LogEvent("DocumentService.cs", "UploadAsync", paramsJson, resp.message, 0, clientId.ToString());
                return resp;
            }

            var categories = await _categoryRepo.GetAllAsync();
            var category = categories.FirstOrDefault(c => c.CategoryId == categoryId);
            if (category == null)
            {
                var resp = ResponseHelper.NotFoundResponse("Invalid category.");
                _commonFunctions.LogEvent("DocumentService.cs", "UploadAsync", paramsJson, resp.message, 0, clientId.ToString());
                return resp;
            }

            var (storedName, filePath) = await _fileStorage.SaveFileAsync(fileStream, originalName, clientId);
            var ds = await _documentRepo.UploadDataSetAsync(
                clientId, categoryId, category.CategoryName, storedName, originalName,
                filePath, extension, fileStream.Length, source, clientId);

            var result = await _spResponse.FromCommandDataSetAsync(ds);
            _commonFunctions.LogEvent("DocumentService.cs", "UploadAsync", paramsJson, result.message, result.status ? 0 : 1, clientId.ToString());
            return result;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("DocumentService.cs", "UploadAsync", paramsJson, ex.ToString(), 1, clientId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetHistoryAsync(DocumentHistoryFilter filter)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(filter.ClientId, filter.CategoryId);
        try
        {
            var ds = await _documentRepo.GetHistoryDataSetAsync(
                filter.ClientId, filter.CategoryId, filter.FromDate, filter.ToDate, filter.SearchFileName);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("DocumentService.cs", "GetHistoryAsync", paramsJson, resp.message, 0, filter.ClientId?.ToString() ?? "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("DocumentService.cs", "GetHistoryAsync", paramsJson, ex.ToString(), 1, filter.ClientId?.ToString() ?? "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetDashboardAsync(long clientId)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(clientId);
        try
        {
            var statsDs = await _documentRepo.GetDashboardStatsDataSetAsync(clientId);
            var userDs = await _userRepo.GetByIdDataSetAsync(clientId);

            var combined = new DataSet();
            if (userDs.Tables.Count > 0)
                combined.Tables.Add(userDs.Tables[0].Copy());
            if (statsDs.Tables.Count > 0)
                combined.Tables.Add(statsDs.Tables[0].Copy());
            if (statsDs.Tables.Count > 1)
                combined.Tables.Add(statsDs.Tables[1].Copy());

            var resp = await _spResponse.FromDataSetAsync(combined, "Success", "No dashboard data found.");
            _commonFunctions.LogEvent("DocumentService.cs", "GetDashboardAsync", paramsJson, resp.message, 0, clientId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("DocumentService.cs", "GetDashboardAsync", paramsJson, ex.ToString(), 1, clientId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<DocumentDownloadResult> DownloadAsync(long fileId)
    {
        try
        {
            var doc = await _documentRepo.GetByIdAsync(fileId);
            if (doc == null)
                return new DocumentDownloadResult(ResponseHelper.NotFoundResponse("Document not found."), null, null, null);

            var (stream, contentType) = await _fileStorage.GetFileAsync(doc.FilePath);
            return new DocumentDownloadResult(null, stream, contentType, doc.OriginalFileName);
        }
        catch (Exception ex)
        {
            var paramsJson = await _commonFunctions.StringParamsToJson(fileId);
            _commonFunctions.LogEvent("DocumentService.cs", "DownloadAsync", paramsJson, ex.ToString(), 1, fileId.ToString());
            return new DocumentDownloadResult(ResponseHelper.InternalErrorResponse(), null, null, null);
        }
    }
}
