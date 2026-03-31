using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Catalog.Api.Persistence;
using SelfRestaurant.Catalog.Api.Persistence.Entities;

namespace SelfRestaurant.Catalog.Api.Controllers;

[ApiController]
public sealed class CatalogController : ControllerBase
{
    private readonly CatalogDbContext _db;

    public CatalogController(CatalogDbContext db)
    {
        _db = db;
    }

    [HttpGet("api/branches")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetBranches(CancellationToken cancellationToken)
    {
        var items = await _db.Branches
            .AsNoTracking()
            .Where(x => x.IsActive ?? true)
            .OrderBy(x => x.Name)
            .Select(x => new
            {
                branchId = x.BranchID,
                name = x.Name,
                location = x.Location,
            })
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    [HttpGet("api/branches/{branchId:int}/tables")]
    public async Task<ActionResult<object>> GetBranchTables(int branchId, CancellationToken cancellationToken)
    {
        var branch = await _db.Branches
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.BranchID == branchId && (x.IsActive ?? true), cancellationToken);
        if (branch is null)
        {
            return NotFound();
        }

        var tables = await _db.DiningTables
            .AsNoTracking()
            .Where(x => x.BranchID == branchId && (x.IsActive ?? true))
            .Include(x => x.Status)
            .OrderBy(x => x.TableID)
            .Select(x => new
            {
                tableId = x.TableID,
                branchId = x.BranchID,
                displayTableNumber = x.TableID,
                numberOfSeats = x.NumberOfSeats,
                statusName = x.Status.StatusName,
                isAvailable = x.Status.StatusCode == "AVAILABLE",
            })
            .ToListAsync(cancellationToken);

        return Ok(new
        {
            branchName = branch.Name,
            tables,
        });
    }

    [HttpGet("api/branches/{branchId:int}/menu")]
    public async Task<ActionResult<object>> GetMenu(int branchId, [FromQuery] DateOnly? date, CancellationToken cancellationToken)
    {
        var branch = await _db.Branches
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.BranchID == branchId && (x.IsActive ?? true), cancellationToken);
        if (branch is null)
        {
            return NotFound();
        }

        var menuDate = date ?? DateOnly.FromDateTime(DateTime.Now);
        var menu = await _db.Menus
            .AsNoTracking()
            .Where(x => x.BranchID == branchId && (x.IsActive ?? true) && (x.Date == null || x.Date == menuDate))
            .OrderByDescending(x => x.Date)
            .FirstOrDefaultAsync(cancellationToken);

        if (menu is null)
        {
            menu = await _db.Menus
                .AsNoTracking()
                .Where(x => x.BranchID == branchId && (x.IsActive ?? true))
                .OrderByDescending(x => x.Date)
                .FirstOrDefaultAsync(cancellationToken);
        }

        if (menu is null)
        {
            return Ok(new
            {
                branchId = branch.BranchID,
                branchName = branch.Name,
                categories = Array.Empty<object>(),
            });
        }

        var categories = await _db.MenuCategory
            .AsNoTracking()
            .Where(x => x.MenuID == menu.MenuID
                && (x.IsActive ?? true)
                && (x.Category.IsActive ?? true))
            .Include(x => x.Category)
            .OrderBy(x => x.Category.DisplayOrder)
            .ThenBy(x => x.Category.Name)
            .ToListAsync(cancellationToken);

        var menuCategories = new List<object>(categories.Count);
        foreach (var mc in categories)
        {
            var dishes = await _db.CategoryDish
                .AsNoTracking()
                .Where(x => x.MenuCategoryID == mc.MenuCategoryID && (x.IsAvailable ?? true))
                .Include(x => x.Dish)
                .OrderBy(x => x.DisplayOrder)
                .ThenBy(x => x.Dish.Name)
                .Select(x => new
                {
                    dishId = x.Dish.DishID,
                    name = x.Dish.Name,
                    description = x.Dish.Description,
                    price = x.Dish.Price,
                    image = x.Dish.Image,
                    unit = x.Dish.Unit,
                    isVegetarian = x.Dish.IsVegetarian ?? false,
                    isDailySpecial = x.Dish.IsDailySpecial ?? false,
                    available = x.Dish.Available ?? true,
                    ingredients = x.Dish.DishIngredients
                        .Select(i => new
                        {
                            name = i.Ingredient.Name,
                            quantity = i.QuantityPerDish,
                            unit = i.Ingredient.Unit,
                        })
                        .ToList(),
                })
                .ToListAsync(cancellationToken);

            menuCategories.Add(new
            {
                categoryId = mc.CategoryID,
                categoryName = mc.Category.Name,
                displayOrder = mc.Category.DisplayOrder ?? 0,
                dishes,
            });
        }

        return Ok(new
        {
            branchId = branch.BranchID,
            branchName = branch.Name,
            categories = menuCategories,
        });
    }

    [HttpGet("api/tables/qr/{code}")]
    public async Task<ActionResult<object>> GetTableByQr(string code, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return BadRequest();
        }

        var table = await _db.DiningTables
            .AsNoTracking()
            .Where(x => x.QRCode == code && (x.IsActive ?? true))
            .Select(x => new
            {
                tableId = x.TableID,
                branchId = x.BranchID,
                displayTableNumber = x.TableID,
            })
            .FirstOrDefaultAsync(cancellationToken);

        return table is null ? NotFound() : Ok(table);
    }

    [HttpGet("api/internal/tables/{tableId:int}")]
    public async Task<ActionResult<object>> GetInternalTable(int tableId, CancellationToken cancellationToken)
    {
        var table = await _db.DiningTables
            .AsNoTracking()
            .Include(x => x.Status)
            .Where(x => x.TableID == tableId && (x.IsActive ?? true))
            .Select(x => new
            {
                tableId = x.TableID,
                branchId = x.BranchID,
                qrCode = x.QRCode,
                isActive = x.IsActive ?? true,
                statusId = x.StatusID,
                statusCode = x.Status != null ? x.Status.StatusCode : null,
                statusName = x.Status != null ? x.Status.StatusName : null,
            })
            .FirstOrDefaultAsync(cancellationToken);

        return table is null ? NotFound() : Ok(table);
    }

    [HttpGet("api/internal/dishes/{dishId:int}")]
    public async Task<ActionResult<object>> GetInternalDish(int dishId, CancellationToken cancellationToken)
    {
        var dish = await _db.Dishes
            .AsNoTracking()
            .Where(x => x.DishID == dishId && (x.IsActive ?? true))
            .Select(x => new
            {
                dishId = x.DishID,
                name = x.Name,
                price = x.Price,
                unit = x.Unit,
                image = x.Image,
                isActive = x.IsActive ?? true,
                available = x.Available ?? true,
            })
            .FirstOrDefaultAsync(cancellationToken);

        return dish is null ? NotFound() : Ok(dish);
    }

    [HttpGet("api/internal/table-statuses/{statusCode}")]
    public async Task<ActionResult<object>> GetInternalTableStatus(string statusCode, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(statusCode))
        {
            return BadRequest();
        }

        var normalized = statusCode.Trim().ToUpperInvariant();
        var status = await _db.TableStatus
            .AsNoTracking()
            .Where(x => x.StatusCode == normalized)
            .Select(x => new
            {
                statusId = x.StatusID,
                statusCode = x.StatusCode,
                statusName = x.StatusName,
            })
            .FirstOrDefaultAsync(cancellationToken);

        return status is null ? NotFound() : Ok(status);
    }

    [HttpGet("api/categories")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetCategories([FromQuery] bool includeInactive = false, CancellationToken cancellationToken = default)
    {
        var query = _db.Categories.AsNoTracking().AsQueryable();
        if (!includeInactive)
        {
            query = query.Where(x => x.IsActive ?? true);
        }

        var categories = await query
            .OrderBy(x => x.DisplayOrder)
            .ThenBy(x => x.Name)
            .Select(x => new
            {
                categoryId = x.CategoryID,
                name = x.Name,
                description = x.Description,
                displayOrder = x.DisplayOrder ?? 0,
                isActive = x.IsActive ?? true,
            })
            .ToListAsync(cancellationToken);

        return Ok(categories);
    }

    [HttpPost("api/categories")]
    public async Task<ActionResult> CreateCategory([FromBody] CategoryUpsertRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest("Name is required.");
        }

        var entity = new Categories
        {
            Name = request.Name.Trim(),
            Description = request.Description,
            DisplayOrder = request.DisplayOrder,
            IsActive = true,
        };

        _db.Categories.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetCategories), new { id = entity.CategoryID }, new { categoryId = entity.CategoryID });
    }

    [HttpPut("api/categories/{categoryId:int}")]
    public async Task<ActionResult> UpdateCategory(int categoryId, [FromBody] CategoryUpsertRequest request, CancellationToken cancellationToken)
    {
        var entity = await _db.Categories.FirstOrDefaultAsync(x => x.CategoryID == categoryId, cancellationToken);
        if (entity is null)
        {
            return NotFound();
        }

        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest("Name is required.");
        }

        entity.Name = request.Name.Trim();
        entity.Description = request.Description;
        entity.DisplayOrder = request.DisplayOrder;
        entity.IsActive = request.IsActive;
        entity.UpdatedAt = DateTime.Now;

        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpDelete("api/categories/{categoryId:int}")]
    public async Task<ActionResult> DeleteCategory(int categoryId, CancellationToken cancellationToken)
    {
        var entity = await _db.Categories.FirstOrDefaultAsync(x => x.CategoryID == categoryId, cancellationToken);
        if (entity is null)
        {
            return NotFound();
        }

        entity.IsActive = false;
        entity.UpdatedAt = DateTime.Now;
        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    public sealed record CategoryUpsertRequest(string Name, string? Description, int DisplayOrder, bool IsActive = true);
}
