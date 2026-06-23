using Asp.Versioning;
using DMS.Application.DTOs.Categories;
using DMS.Application.DTOs.Common;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/categories")]
[Authorize]
public class CategoriesController : ApiControllerBase
{
    private readonly CategoryService _categoryService;

    public CategoriesController(CategoryService categoryService) => _categoryService = categoryService;

    [HttpGet]
    public Task<Response> GetAll([FromQuery] bool includeInactive = false)
    {
        if (includeInactive && !User.IsInRole("SuperAdmin"))
            includeInactive = false;

        return _categoryService.GetAllAsync(includeInactive);
    }

    [HttpPost]
    [Authorize(Roles = "SuperAdmin")]
    public Task<Response> Create([FromBody] CreateCategoryRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _categoryService.AddAsync(request, userId);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "SuperAdmin")]
    public Task<Response> Update(int id, [FromBody] UpdateCategoryRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _categoryService.UpdateAsync(id, request, userId);
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "SuperAdmin")]
    public Task<Response> Delete(int id)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _categoryService.DeleteAsync(id, userId);
    }
}
