using DMS.Application.Interfaces;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Services;

public class LocalFileStorageService : IFileStorageService
{
    private readonly string _basePath;
    private static readonly string[] AllowedExtensions = { ".jpg", ".jpeg", ".png", ".pdf" };
    private const long MinSize = 500 * 1024;
    private const long MaxSize = 5 * 1024 * 1024;

    public LocalFileStorageService(IConfiguration configuration)
    {
        _basePath = configuration["FileStorage:BasePath"] ?? Path.Combine(Directory.GetCurrentDirectory(), "uploads");
        if (!Directory.Exists(_basePath))
            Directory.CreateDirectory(_basePath);
    }

    public async Task<(string storedName, string filePath)> SaveFileAsync(byte[] content, string originalName, long clientId)
    {
        var dateFolder = DateTime.UtcNow.ToString("yyyyMMdd");
        var folder = Path.Combine(_basePath, clientId.ToString(), dateFolder);
        Directory.CreateDirectory(folder);

        var storedName = $"{Guid.NewGuid():N}{Path.GetExtension(originalName)}";
        var fullPath = Path.Combine(folder, storedName);
        await File.WriteAllBytesAsync(fullPath, content);

        return (storedName, fullPath);
    }

    public Task<(Stream stream, string contentType)?> TryGetFileAsync(string filePath)
    {
        if (!File.Exists(filePath))
            return Task.FromResult<(Stream, string)?>(null);

        var stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
        var contentType = GetContentType(Path.GetExtension(filePath));
        return Task.FromResult<(Stream, string)?>((stream, contentType));
    }

    public string GetContentType(string extension) =>
        extension.ToLowerInvariant() switch
        {
            ".pdf" => "application/pdf",
            ".png" => "image/png",
            ".jpg" or ".jpeg" => "image/jpeg",
            _ => "application/octet-stream"
        };

    public bool IsAllowedExtension(string extension) =>
        AllowedExtensions.Contains(extension.ToLowerInvariant());

    public bool IsAllowedSize(long size) => size >= MinSize && size <= MaxSize;
}
