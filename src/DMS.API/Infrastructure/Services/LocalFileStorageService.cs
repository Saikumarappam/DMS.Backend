using DMS.Application.Interfaces;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Services;

public class LocalFileStorageService : IFileStorageService
{
    private readonly string _basePath;
    private readonly string[] _allowedExtensions;

    public IReadOnlyList<string> AllowedExtensions => _allowedExtensions;
    public long MinSizeBytes { get; }
    public long MaxSizeBytes { get; }

    public LocalFileStorageService(IConfiguration configuration)
    {
        _basePath = configuration["FileStorage:BasePath"] ?? Path.Combine(Directory.GetCurrentDirectory(), "uploads");
        if (!Directory.Exists(_basePath))
            Directory.CreateDirectory(_basePath);

        _allowedExtensions = configuration
            .GetSection("FileStorage:AllowedExtensions")
            .Get<string[]>()
            ?.Select(NormalizeExtension)
            .Where(e => !string.IsNullOrEmpty(e))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray() ?? [];

        if (_allowedExtensions.Length == 0)
            throw new InvalidOperationException("FileStorage:AllowedExtensions must contain at least one extension.");

        MinSizeBytes = configuration.GetValue<long>("FileStorage:MinSizeBytes");
        MaxSizeBytes = configuration.GetValue<long>("FileStorage:MaxSizeBytes");

        if (MinSizeBytes <= 0 || MaxSizeBytes <= 0 || MinSizeBytes > MaxSizeBytes)
            throw new InvalidOperationException("FileStorage:MinSizeBytes and FileStorage:MaxSizeBytes must be positive and MinSizeBytes must not exceed MaxSizeBytes.");
    }


    //public async Task<(string storedName, string filePath)> SaveFileAsync(byte[] content, string fileName, long clientId, string categoryName)
    //{
    //    var now = DateTime.UtcNow;

    //    var safeCategory = string.Concat(categoryName.Split(Path.GetInvalidFileNameChars()));

    //    var folder = Path.Combine(
    //        clientId.ToString(),
    //        safeCategory,
    //        now.Year.ToString(),
    //        now.Month.ToString("00"),
    //        now.Day.ToString("00"));

    //    var physicalFolder = Path.Combine(_basePath, folder);

    //    Directory.CreateDirectory(physicalFolder);

    //    var extension = Path.GetExtension(fileName);

    //    var storedName = $"{Guid.NewGuid():N}{extension}";

    //    var fullPath = Path.Combine(physicalFolder, storedName);

    //    await File.WriteAllBytesAsync(fullPath, content);

    //    return (storedName, Path.Combine(folder, storedName));
    //}


    public async Task<(string storedName, string filePath)> SaveFileAsync(byte[] content, string fileName, long clientId, string categoryName)
    {
        var now = DateTime.UtcNow;

        var safeCategory = string.Concat(
            categoryName.Split(Path.GetInvalidFileNameChars()));

        var folder = Path.Combine(
            clientId.ToString(),
            safeCategory,
            now.Year.ToString(),
            now.Month.ToString("00"),
            now.Day.ToString("00"));

        var physicalFolder = Path.Combine(_basePath, folder);

        Directory.CreateDirectory(physicalFolder);

        var extension = Path.GetExtension(fileName);

        var storedName = $"{Guid.NewGuid():N}{extension}";

        var fullPath = Path.Combine(
            physicalFolder,
            fileName);

        await File.WriteAllBytesAsync(fullPath, content);

        // Store complete physical path
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
        _allowedExtensions.Contains(NormalizeExtension(extension), StringComparer.OrdinalIgnoreCase);

    public bool IsAllowedSize(long size) => size >= 0 && size <= MaxSizeBytes;

    public string GetAllowedExtensionsErrorMessage() =>
        $"File type not allowed. Supported: {string.Join(", ", _allowedExtensions.Select(e => e.TrimStart('.').ToUpperInvariant()))}.";

    public string GetFileSizeErrorMessage() =>
     $"The uploaded file exceeds the maximum allowed size of {FormatSize(MaxSizeBytes)}.";

    private static string NormalizeExtension(string extension)
    {
        if (string.IsNullOrWhiteSpace(extension))
            return string.Empty;

        var trimmed = extension.Trim().ToLowerInvariant();
        return trimmed.StartsWith('.') ? trimmed : $".{trimmed}";
    }

    private static string FormatSize(long bytes) =>
        bytes >= 1024 * 1024
            ? $"{bytes / (1024.0 * 1024.0):0.#}MB"
            : $"{bytes / 1024.0:0.#}KB";
}
