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

    public async Task<(string storedName, string filePath)> SaveFileAsync(Stream stream, string originalName, long clientId)
    {
        var clientFolder = Path.Combine(_basePath, clientId.ToString());
        if (!Directory.Exists(clientFolder))
            Directory.CreateDirectory(clientFolder);

        var storedName = $"{Guid.NewGuid():N}{Path.GetExtension(originalName)}";
        var fullPath = Path.Combine(clientFolder, storedName);

        using var fileStream = new FileStream(fullPath, FileMode.Create, FileAccess.Write);
        await stream.CopyToAsync(fileStream);

        return (storedName, fullPath);
    }

    public Task<(Stream stream, string contentType)> GetFileAsync(string filePath)
    {
        var stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        var contentType = ext switch
        {
            ".pdf" => "application/pdf",
            ".png" => "image/png",
            ".jpg" or ".jpeg" => "image/jpeg",
            _ => "application/octet-stream"
        };
        return Task.FromResult<(Stream, string)>((stream, contentType));
    }

    public bool IsAllowedExtension(string extension) =>
        AllowedExtensions.Contains(extension.ToLowerInvariant());

    public bool IsAllowedSize(long size) => size >= MinSize && size <= MaxSize;
}
