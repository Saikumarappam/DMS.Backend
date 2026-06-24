using System.Data;
using DMS.API.Helpers;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Documents;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using Newtonsoft.Json;

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

            using var buffer = new MemoryStream();
            await fileStream.CopyToAsync(buffer);
            var fileBytes = buffer.ToArray();

            if (!_fileStorage.IsAllowedSize(fileBytes.Length))
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

            var fileBase64 = Convert.ToBase64String(fileBytes);
            var (storedName, filePath) = await _fileStorage.SaveFileAsync(fileBytes, originalName, clientId);
            var ds = await _documentRepo.UploadDataSetAsync(
                clientId, categoryId, category.CategoryName, storedName, originalName,
                filePath, extension, fileBytes.Length, source, clientId, fileBase64);

            var result = await _spResponse.FromCommandDataSetAsync(ds, "Document uploaded successfully.");
            if (result.status)
            {
                result.jsonstring = JsonConvert.SerializeObject(new
                {
                    fileId = result.jsonstring,
                    fileName = storedName,
                    originalFileName = originalName,
                    fileExtension = extension,
                    fileSize = fileBytes.Length,
                    contentType = _fileStorage.GetContentType(extension),
                    fileBase64
                });
            }

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

    public async Task<Response> DownloadAsync(long fileId)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(fileId);
        try
        {
            var doc = await _documentRepo.GetByIdAsync(fileId);
            if (doc == null)
            {
                var notFound = ResponseHelper.NotFoundResponse("Document not found.");
                _commonFunctions.LogEvent("DocumentService.cs", "DownloadAsync", paramsJson, notFound.message, 0, fileId.ToString());
                return notFound;
            }

            string? fileBase64 = null;

            try
            {
                if (!string.IsNullOrWhiteSpace(doc.FilePath))
                {
                    var fileResult = await _fileStorage.TryGetFileAsync(doc.FilePath);
                    if (fileResult.HasValue)
                    {
                        await using var stream = fileResult.Value.stream;
                        using var ms = new MemoryStream();
                        await stream.CopyToAsync(ms);
                        fileBase64 = Convert.ToBase64String(ms.ToArray());
                    }
                }
            }
            catch (Exception readEx)
            {
                _commonFunctions.LogEvent("DocumentService.cs", "DownloadAsync", paramsJson,
                    $"File path read failed, using stored base64. {readEx.Message}", 0, fileId.ToString());
            }

            if (string.IsNullOrWhiteSpace(fileBase64))
                fileBase64 = doc.FileBase64;

            if (string.IsNullOrWhiteSpace(fileBase64))
            {
                var unavailable = ResponseHelper.NotFoundResponse("Document file is not available.");
                _commonFunctions.LogEvent("DocumentService.cs", "DownloadAsync", paramsJson, unavailable.message, 0, fileId.ToString());
                return unavailable;
            }

            var resp = ResponseHelper.Success("Document retrieved successfully.");
            resp.jsonstring = JsonConvert.SerializeObject(new
            {
                fileId = doc.FileId,
                fileName = doc.FileName,
                originalFileName = doc.OriginalFileName,
                fileExtension = doc.FileExtension,
                fileSize = doc.FileSize,
                contentType = _fileStorage.GetContentType(doc.FileExtension),
                fileBase64
            });

            _commonFunctions.LogEvent("DocumentService.cs", "DownloadAsync", paramsJson, resp.message, 0, fileId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("DocumentService.cs", "DownloadAsync", paramsJson, ex.ToString(), 1, fileId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }
}
