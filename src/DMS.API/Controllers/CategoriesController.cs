using Asp.Versioning;
using DMS.Application.DTOs.Categories;
using DMS.Application.DTOs.Common;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

/// <summary>Document category management.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/categories")]
[Authorize]
[Tags("Categories")]
[Produces("application/json")]
public class CategoriesController : ApiControllerBase
{
    private readonly CategoryService _categoryService;

    public CategoriesController(CategoryService categoryService) => _categoryService = categoryService;

    /// <summary>List document categories.</summary>
    /// <remarks>Frontend: <c>UploadDocumentScreen</c>, <c>HistoryScreen</c>, <c>CategoryManagementScreen</c>. includeInactive is SuperAdmin-only.</remarks>
    [HttpGet]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<Response> GetAll([FromQuery] bool includeInactive = false)
    {
        if (includeInactive && !User.IsInRole("SuperAdmin"))
            includeInactive = false;

        return _categoryService.GetAllAsync(includeInactive);
    }

    /// <summary>Create a new category.</summary>
    /// <remarks>Frontend: <c>CategoryManagementScreen</c> (<c>/admin/categories</c>). SuperAdmin only.</remarks>
    [HttpPost]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> Create([FromBody] CreateCategoryRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _categoryService.AddAsync(request, userId);
    }

    /// <summary>Update an existing category.</summary>
    /// <remarks>Frontend: <c>CategoryManagementScreen</c>. SuperAdmin only.</remarks>
    [HttpPut("{id}")]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> Update(int id, [FromBody] UpdateCategoryRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _categoryService.UpdateAsync(id, request, userId);
    }

    /// <summary>Deactivate (soft-delete) a category.</summary>
    /// <remarks>Frontend: <c>CategoryManagementScreen</c>. SuperAdmin only.</remarks>
    [HttpDelete("{id}")]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> Delete(int id)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _categoryService.DeleteAsync(id, userId);
    }
}
