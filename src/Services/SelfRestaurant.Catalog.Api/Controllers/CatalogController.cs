using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Catalog.Api.Persistence;
using SelfRestaurant.Catalog.Api.Persistence.Entities;

namespace SelfRestaurant.Catalog.Api.Controllers;

[ApiController]
public sealed class CatalogController : ControllerBase
{
    private readonly CatalogDbContext _db;
    private readonly ILogger<CatalogController> _logger;
    private readonly IHostEnvironment _environment;

    public CatalogController(CatalogDbContext db, ILogger<CatalogController> logger, IHostEnvironment environment)
    {
        _db = db;
        _logger = logger;
        _environment = environment;
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
            var rawDishes = await _db.CategoryDish
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

            var orderableDishIds = await FilterOrderableDishIdsAsync(rawDishes.Select(x => x.dishId), cancellationToken);
            // Keep dishes visible in the menu even when they are temporarily not orderable,
            // so the MVC-like customer flow can show "Tạm hết" instead of silently hiding them.
            var dishes = rawDishes
                .Select(x => new
                {
                    x.dishId,
                    x.name,
                    x.description,
                    x.price,
                    x.image,
                    x.unit,
                    x.isVegetarian,
                    x.isDailySpecial,
                    available = x.available && orderableDishIds.Contains(x.dishId),
                    x.ingredients,
                })
                .ToList();

            if (dishes.Count == 0)
            {
                continue;
            }

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

    [HttpGet("api/internal/tables:batch")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetInternalTablesBatch([FromQuery] int[] ids, CancellationToken cancellationToken)
    {
        var tableIds = ids.Where(x => x > 0).Distinct().ToArray();
        if (tableIds.Length == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var tables = await _db.DiningTables
            .AsNoTracking()
            .Include(x => x.Status)
            .Where(x => tableIds.Contains(x.TableID) && (x.IsActive ?? true))
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
            .ToListAsync(cancellationToken);

        return Ok(tables);
    }

    [HttpPost("api/dev/reset-test-state")]
    public async Task<ActionResult<object>> ResetDevTestState(CancellationToken cancellationToken)
    {
        if (!_environment.IsDevelopment())
        {
            return NotFound();
        }

        var availableStatusId = await _db.TableStatus
            .Where(x => x.StatusCode == "AVAILABLE")
            .Select(x => (int?)x.StatusID)
            .FirstOrDefaultAsync(cancellationToken);

        if (!availableStatusId.HasValue)
        {
            return Problem("Missing AVAILABLE table status.", statusCode: StatusCodes.Status500InternalServerError);
        }

        var tables = await _db.DiningTables
            .Where(x => x.IsActive ?? true)
            .ToListAsync(cancellationToken);

        foreach (var table in tables)
        {
            table.CurrentOrderID = null;
            table.StatusID = availableStatusId.Value;
            table.UpdatedAt = DateTime.Now;
        }

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            success = true,
            resetTables = tables.Count
        });
    }

    [HttpGet("api/internal/dishes/{dishId:int}")]
    public async Task<ActionResult<object>> GetInternalDish(int dishId, CancellationToken cancellationToken)
    {
        var orderableDishIds = await FilterOrderableDishIdsAsync(new[] { dishId }, cancellationToken);

        var dish = await _db.Dishes
            .AsNoTracking()
            .Include(x => x.Category)
            .Where(x => x.DishID == dishId && (x.IsActive ?? true))
            .Select(x => new
            {
                dishId = x.DishID,
                name = x.Name,
                categoryId = x.CategoryID,
                categoryName = x.Category != null ? x.Category.Name : null,
                price = x.Price,
                unit = x.Unit,
                image = x.Image,
                isActive = x.IsActive ?? true,
                available = (x.Available ?? true) && orderableDishIds.Contains(x.DishID),
            })
            .FirstOrDefaultAsync(cancellationToken);

        return dish is null ? NotFound() : Ok(dish);
    }

    [HttpGet("api/internal/dishes:batch")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetInternalDishesBatch([FromQuery] int[] ids, CancellationToken cancellationToken)
    {
        var dishIds = ids.Where(x => x > 0).Distinct().ToArray();
        if (dishIds.Length == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var orderableDishIds = await FilterOrderableDishIdsAsync(dishIds, cancellationToken);
        var dishes = await _db.Dishes
            .AsNoTracking()
            .Include(x => x.Category)
            .Where(x => dishIds.Contains(x.DishID) && (x.IsActive ?? true))
            .Select(x => new
            {
                dishId = x.DishID,
                name = x.Name,
                categoryId = x.CategoryID,
                categoryName = x.Category != null ? x.Category.Name : null,
                price = x.Price,
                unit = x.Unit,
                image = x.Image,
                isActive = x.IsActive ?? true,
                available = (x.Available ?? true) && orderableDishIds.Contains(x.DishID),
            })
            .ToListAsync(cancellationToken);

        return Ok(dishes);
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

    [HttpGet("api/internal/branches:batch")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetInternalBranchesBatch([FromQuery] int[] ids, CancellationToken cancellationToken)
    {
        var branchIds = ids.Where(x => x > 0).Distinct().ToArray();
        if (branchIds.Length == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var branches = await _db.Branches
            .AsNoTracking()
            .Where(x => branchIds.Contains(x.BranchID) && (x.IsActive ?? true))
            .Select(x => new
            {
                branchId = x.BranchID,
                name = x.Name,
                location = x.Location,
                isActive = x.IsActive ?? true,
            })
            .ToListAsync(cancellationToken);

        return Ok(branches);
    }

    [HttpGet("api/internal/branches/{branchId:int}/table-ids")]
    public async Task<ActionResult<IReadOnlyList<int>>> GetInternalBranchTableIds(int branchId, CancellationToken cancellationToken)
    {
        var ids = await _db.DiningTables
            .AsNoTracking()
            .Where(x => x.BranchID == branchId && (x.IsActive ?? true))
            .OrderBy(x => x.TableID)
            .Select(x => x.TableID)
            .ToListAsync(cancellationToken);

        return Ok(ids);
    }

    [HttpPost("api/internal/tables/{tableId:int}/occupy")]
    public async Task<ActionResult> OccupyInternalTable(
        int tableId,
        [FromBody] TableOccupancyRequest request,
        CancellationToken cancellationToken)
    {
        var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId && (x.IsActive ?? true), cancellationToken);
        if (table is null)
        {
            return NotFound();
        }

        var occupiedId = await _db.TableStatus
            .Where(x => x.StatusCode == "OCCUPIED")
            .Select(x => (int?)x.StatusID)
            .FirstOrDefaultAsync(cancellationToken);

        if (occupiedId is null)
        {
            return BadRequest("Status 'OCCUPIED' is missing.");
        }

        table.StatusID = occupiedId.Value;
        table.CurrentOrderID = request.CurrentOrderId;
        table.UpdatedAt = DateTime.Now;
        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPost("api/internal/tables/{tableId:int}/release")]
    public async Task<ActionResult> ReleaseInternalTable(int tableId, CancellationToken cancellationToken)
    {
        var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId && (x.IsActive ?? true), cancellationToken);
        if (table is null)
        {
            return NotFound();
        }

        var availableId = await _db.TableStatus
            .Where(x => x.StatusCode == "AVAILABLE")
            .Select(x => (int?)x.StatusID)
            .FirstOrDefaultAsync(cancellationToken);

        if (availableId is null)
        {
            return BadRequest("Status 'AVAILABLE' is missing.");
        }

        table.StatusID = availableId.Value;
        table.CurrentOrderID = null;
        table.UpdatedAt = DateTime.Now;
        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPost("api/internal/inventory/consume")]
    public async Task<ActionResult<IngredientConsumptionResponse>> ConsumeInventoryForOrder(
        [FromBody] IngredientConsumptionRequest request,
        CancellationToken cancellationToken)
    {
        var items = (request.Items ?? Array.Empty<IngredientConsumptionItem>())
            .Where(x => x.DishId > 0 && x.Quantity > 0)
            .GroupBy(x => x.DishId)
            .Select(g => new { DishId = g.Key, Quantity = g.Sum(x => x.Quantity) })
            .ToList();

        if (items.Count == 0)
        {
            return BadRequest(new IngredientConsumptionResponse(
                false,
                "Đơn hàng không có món hợp lệ để trừ kho.",
                Array.Empty<IngredientConsumptionIssue>()));
        }

        var dishIds = items.Select(x => x.DishId).Distinct().ToArray();
        var recipes = await _db.DishIngredients
            .Include(x => x.Ingredient)
            .Where(x => dishIds.Contains(x.DishID) && x.Ingredient.IsActive)
            .ToListAsync(cancellationToken);

        if (recipes.Count == 0)
        {
            return Ok(new IngredientConsumptionResponse(
                true,
                "Không có công thức nguyên liệu cần trừ cho đơn hàng này.",
                Array.Empty<IngredientConsumptionIssue>()));
        }

        var itemLookup = items.ToDictionary(x => x.DishId, x => x.Quantity);
        var requirements = recipes
            .GroupBy(x => x.IngredientID)
            .Select(g =>
            {
                var first = g.First();
                var requiredQuantity = g.Sum(recipe => recipe.QuantityPerDish * itemLookup.GetValueOrDefault(recipe.DishID, 0));
                return new
                {
                    Ingredient = first.Ingredient,
                    RequiredQuantity = requiredQuantity
                };
            })
            .Where(x => x.RequiredQuantity > 0)
            .ToList();

        var insufficient = requirements
            .Where(x => x.Ingredient.CurrentStock < x.RequiredQuantity)
            .Select(x => new IngredientConsumptionIssue(
                x.Ingredient.IngredientID,
                x.Ingredient.Name,
                x.RequiredQuantity,
                x.Ingredient.CurrentStock,
                x.Ingredient.Unit))
            .ToList();

        if (insufficient.Count > 0)
        {
            return Conflict(new IngredientConsumptionResponse(
                false,
                "Không đủ nguyên liệu để bắt đầu chế biến đơn này.",
                insufficient));
        }

        foreach (var requirement in requirements)
        {
            requirement.Ingredient.CurrentStock -= requirement.RequiredQuantity;
        }

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new IngredientConsumptionResponse(
            true,
            "Đã trừ kho nguyên liệu cho đơn hàng.",
            Array.Empty<IngredientConsumptionIssue>()));
    }

    [HttpPost("api/internal/inventory/validate")]
    public async Task<ActionResult<IngredientConsumptionResponse>> ValidateInventoryForOrder(
        [FromBody] IngredientConsumptionRequest request,
        CancellationToken cancellationToken)
    {
        var items = (request.Items ?? Array.Empty<IngredientConsumptionItem>())
            .Where(x => x.DishId > 0 && x.Quantity > 0)
            .GroupBy(x => x.DishId)
            .Select(g => new { DishId = g.Key, Quantity = g.Sum(x => x.Quantity) })
            .ToList();

        if (items.Count == 0)
        {
            return BadRequest(new IngredientConsumptionResponse(
                false,
                "Đơn hàng không có món hợp lệ để kiểm tra kho.",
                Array.Empty<IngredientConsumptionIssue>()));
        }

        var dishIds = items.Select(x => x.DishId).Distinct().ToArray();
        var recipes = await _db.DishIngredients
            .Include(x => x.Ingredient)
            .Where(x => dishIds.Contains(x.DishID) && x.Ingredient.IsActive)
            .ToListAsync(cancellationToken);

        if (recipes.Count == 0)
        {
            return Ok(new IngredientConsumptionResponse(
                true,
                "Không có công thức nguyên liệu cần kiểm tra cho đơn hàng này.",
                Array.Empty<IngredientConsumptionIssue>()));
        }

        var itemLookup = items.ToDictionary(x => x.DishId, x => x.Quantity);
        var requirements = recipes
            .GroupBy(x => x.IngredientID)
            .Select(g =>
            {
                var first = g.First();
                var requiredQuantity = g.Sum(recipe => recipe.QuantityPerDish * itemLookup.GetValueOrDefault(recipe.DishID, 0));
                return new
                {
                    Ingredient = first.Ingredient,
                    RequiredQuantity = requiredQuantity
                };
            })
            .Where(x => x.RequiredQuantity > 0)
            .ToList();

        var insufficient = requirements
            .Where(x => x.Ingredient.CurrentStock < x.RequiredQuantity)
            .Select(x => new IngredientConsumptionIssue(
                x.Ingredient.IngredientID,
                x.Ingredient.Name,
                x.RequiredQuantity,
                x.Ingredient.CurrentStock,
                x.Ingredient.Unit))
            .ToList();

        if (insufficient.Count > 0)
        {
            return Conflict(new IngredientConsumptionResponse(
                false,
                "Không đủ nguyên liệu để tiếp tục gửi món này xuống bếp.",
                insufficient));
        }

        return Ok(new IngredientConsumptionResponse(
            true,
            "Đủ nguyên liệu để tiếp tục gửi món.",
            Array.Empty<IngredientConsumptionIssue>()));
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
    public sealed record TableOccupancyRequest(int? CurrentOrderId);
    public sealed record IngredientConsumptionItem(int DishId, int Quantity);
    public sealed record IngredientConsumptionIssue(
        int IngredientId,
        string IngredientName,
        decimal RequiredQuantity,
        decimal AvailableQuantity,
        string? Unit);
    public sealed record IngredientConsumptionRequest(int OrderId, IReadOnlyList<IngredientConsumptionItem>? Items);
    public sealed record IngredientConsumptionResponse(
        bool Success,
        string? Message,
        IReadOnlyList<IngredientConsumptionIssue> Issues);

    private async Task<HashSet<int>> FilterOrderableDishIdsAsync(IEnumerable<int> candidateDishIds, CancellationToken cancellationToken)
    {
        var dishIds = candidateDishIds
            .Where(x => x > 0)
            .Distinct()
            .ToArray();

        if (dishIds.Length == 0)
        {
            return new HashSet<int>();
        }

        // Availability has to come from the Catalog service's current owned data.
        // The older hard-coded shared-database query could drift from local runtime
        // state and falsely advertise sold-out dishes as orderable.
        var orderableDishIds = await _db.Dishes
            .AsNoTracking()
            .Where(x => dishIds.Contains(x.DishID)
                && (x.IsActive ?? true)
                && (x.Available ?? true)
                && !x.DishIngredients.Any(di =>
                    !di.Ingredient.IsActive
                    || di.Ingredient.CurrentStock < di.QuantityPerDish))
            .Select(x => x.DishID)
            .ToListAsync(cancellationToken);

        return orderableDishIds.ToHashSet();
    }
}
