using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Catalog.Api.Persistence;
using SelfRestaurant.Catalog.Api.Persistence.Entities;

namespace SelfRestaurant.Catalog.Api.Controllers;

[ApiController]
[Route("api/admin")]
public sealed class AdminCatalogController : ControllerBase
{
    private readonly CatalogDbContext _db;

    public AdminCatalogController(CatalogDbContext db)
    {
        _db = db;
    }

    [HttpGet("dishes")]
    public async Task<ActionResult<PagedResponse<AdminDishResponse>>> GetDishes(
        [FromQuery] string? search,
        [FromQuery] int? categoryId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] bool includeInactive = true,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _db.Dishes
            .AsNoTracking()
            .Include(d => d.Category)
            .AsQueryable();

        if (!includeInactive)
        {
            query = query.Where(d => (d.IsActive ?? false) == true);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var key = search.Trim();
            query = query.Where(d =>
                d.Name.Contains(key) ||
                (d.Description != null && d.Description.Contains(key)));
        }

        if (categoryId is > 0)
        {
            query = query.Where(d => d.CategoryID == categoryId.Value);
        }

        var totalItems = await query.CountAsync(cancellationToken);
        var totalPages = totalItems <= 0 ? 0 : (int)Math.Ceiling(totalItems / (double)pageSize);

        var items = await query
            .OrderBy(d => d.Category.Name)
            .ThenBy(d => d.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(d => new AdminDishResponse(
                d.DishID,
                d.Name,
                d.Price,
                d.CategoryID,
                d.Category.Name,
                d.Description,
                d.Unit,
                d.Image,
                d.IsVegetarian ?? false,
                d.IsDailySpecial ?? false,
                d.Available ?? true,
                d.IsActive ?? false))
            .ToListAsync(cancellationToken);

        return Ok(new PagedResponse<AdminDishResponse>(page, pageSize, totalItems, totalPages, items));
    }

    [HttpGet("dishes/{dishId:int}")]
    public async Task<ActionResult<AdminDishResponse>> GetDishById(int dishId, CancellationToken cancellationToken = default)
    {
        var dish = await _db.Dishes
            .AsNoTracking()
            .Include(d => d.Category)
            .Where(d => d.DishID == dishId)
            .Select(d => new AdminDishResponse(
                d.DishID,
                d.Name,
                d.Price,
                d.CategoryID,
                d.Category.Name,
                d.Description,
                d.Unit,
                d.Image,
                d.IsVegetarian ?? false,
                d.IsDailySpecial ?? false,
                d.Available ?? true,
                d.IsActive ?? false))
            .FirstOrDefaultAsync(cancellationToken);

        return dish is null ? NotFound(new { message = "Dish not found." }) : Ok(dish);
    }

    [HttpPost("dishes")]
    public async Task<ActionResult> CreateDish([FromBody] AdminUpsertDishRequest request, CancellationToken cancellationToken = default)
    {
        var validation = await ValidateDishRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        var entity = new Dishes
        {
            Name = request.Name!.Trim(),
            Price = request.Price!.Value,
            CategoryID = request.CategoryId!.Value,
            Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim(),
            Unit = string.IsNullOrWhiteSpace(request.Unit) ? null : request.Unit.Trim(),
            Image = string.IsNullOrWhiteSpace(request.Image) ? null : request.Image.Trim(),
            IsVegetarian = request.IsVegetarian ?? false,
            IsDailySpecial = request.IsDailySpecial ?? false,
            Available = request.Available ?? true,
            IsActive = request.IsActive ?? true,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now
        };

        _db.Dishes.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Created.", dishId = entity.DishID });
    }

    [HttpPut("dishes/{dishId:int}")]
    public async Task<ActionResult> UpdateDish(int dishId, [FromBody] AdminUpsertDishRequest request, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Dishes.FirstOrDefaultAsync(d => d.DishID == dishId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Dish not found." });
        }

        var validation = await ValidateDishRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        entity.Name = request.Name!.Trim();
        entity.Price = request.Price!.Value;
        entity.CategoryID = request.CategoryId!.Value;
        entity.Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        entity.Unit = string.IsNullOrWhiteSpace(request.Unit) ? null : request.Unit.Trim();
        entity.Image = string.IsNullOrWhiteSpace(request.Image) ? null : request.Image.Trim();
        entity.IsVegetarian = request.IsVegetarian ?? false;
        entity.IsDailySpecial = request.IsDailySpecial ?? false;
        entity.Available = request.Available ?? true;
        entity.IsActive = request.IsActive ?? true;
        entity.UpdatedAt = DateTime.Now;

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Updated." });
    }

    [HttpPost("dishes/{dishId:int}/deactivate")]
    public async Task<IActionResult> DeactivateDish(int dishId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Dishes.FirstOrDefaultAsync(d => d.DishID == dishId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Dish not found." });
        }

        entity.IsActive = false;
        entity.Available = false;
        entity.UpdatedAt = DateTime.Now;
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Deactivated." });
    }

    [HttpGet("dishes/{dishId:int}/ingredients")]
    public async Task<ActionResult<IReadOnlyList<AdminDishIngredientLineResponse>>> GetDishIngredients(int dishId, CancellationToken cancellationToken = default)
    {
        var dishExists = await _db.Dishes.AnyAsync(d => d.DishID == dishId, cancellationToken);
        if (!dishExists)
        {
            return NotFound(new { message = "Dish not found." });
        }

        var selected = await _db.DishIngredients
            .AsNoTracking()
            .Where(di => di.DishID == dishId)
            .ToDictionaryAsync(di => di.IngredientID, di => di.QuantityPerDish, cancellationToken);

        var ingredients = await _db.Ingredients
            .AsNoTracking()
            .OrderBy(i => i.Name)
            .Select(i => new AdminDishIngredientLineResponse(
                i.IngredientID,
                i.Name,
                i.Unit,
                i.CurrentStock,
                i.IsActive,
                selected.ContainsKey(i.IngredientID),
                selected.ContainsKey(i.IngredientID) ? selected[i.IngredientID] : 0))
            .ToListAsync(cancellationToken);

        return Ok(ingredients);
    }

    [HttpPut("dishes/{dishId:int}/ingredients")]
    public async Task<IActionResult> UpdateDishIngredients(
        int dishId,
        [FromBody] UpdateDishIngredientsRequest request,
        CancellationToken cancellationToken = default)
    {
        var dishExists = await _db.Dishes.AnyAsync(d => d.DishID == dishId, cancellationToken);
        if (!dishExists)
        {
            return NotFound(new { message = "Dish not found." });
        }

        var incoming = request.Items ?? Array.Empty<UpdateDishIngredientItem>();
        var cleaned = incoming
            .Where(x => x.IngredientId > 0 && x.QuantityPerDish > 0)
            .GroupBy(x => x.IngredientId)
            .Select(g => g.OrderByDescending(x => x.QuantityPerDish).First())
            .ToList();

        var incomingIds = cleaned.Select(x => x.IngredientId).ToList();
        if (incomingIds.Count > 0)
        {
            var exists = await _db.Ingredients
                .Where(i => incomingIds.Contains(i.IngredientID))
                .Select(i => i.IngredientID)
                .ToListAsync(cancellationToken);
            if (exists.Count != incomingIds.Count)
            {
                return BadRequest(new { message = "Some ingredients are invalid." });
            }
        }

        var current = await _db.DishIngredients.Where(di => di.DishID == dishId).ToListAsync(cancellationToken);
        _db.DishIngredients.RemoveRange(current);

        foreach (var item in cleaned)
        {
            _db.DishIngredients.Add(new DishIngredients
            {
                DishID = dishId,
                IngredientID = item.IngredientId,
                QuantityPerDish = item.QuantityPerDish
            });
        }

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Updated." });
    }

    [HttpGet("ingredients")]
    public async Task<ActionResult<PagedResponse<AdminIngredientResponse>>> GetIngredients(
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] bool includeInactive = true,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _db.Ingredients.AsNoTracking().AsQueryable();
        if (!includeInactive)
        {
            query = query.Where(i => i.IsActive);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var key = search.Trim();
            query = query.Where(i => i.Name.Contains(key) || i.Unit.Contains(key));
        }

        var totalItems = await query.CountAsync(cancellationToken);
        var totalPages = totalItems <= 0 ? 0 : (int)Math.Ceiling(totalItems / (double)pageSize);

        var items = await query
            .OrderBy(i => i.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(i => new AdminIngredientResponse(
                i.IngredientID,
                i.Name,
                i.Unit,
                i.CurrentStock,
                i.ReorderLevel,
                i.IsActive))
            .ToListAsync(cancellationToken);

        return Ok(new PagedResponse<AdminIngredientResponse>(page, pageSize, totalItems, totalPages, items));
    }

    [HttpGet("ingredients/{ingredientId:int}")]
    public async Task<ActionResult<AdminIngredientResponse>> GetIngredientById(int ingredientId, CancellationToken cancellationToken = default)
    {
        var item = await _db.Ingredients
            .AsNoTracking()
            .Where(i => i.IngredientID == ingredientId)
            .Select(i => new AdminIngredientResponse(
                i.IngredientID,
                i.Name,
                i.Unit,
                i.CurrentStock,
                i.ReorderLevel,
                i.IsActive))
            .FirstOrDefaultAsync(cancellationToken);

        return item is null ? NotFound(new { message = "Ingredient not found." }) : Ok(item);
    }

    [HttpPost("ingredients")]
    public async Task<ActionResult> CreateIngredient([FromBody] AdminUpsertIngredientRequest request, CancellationToken cancellationToken = default)
    {
        var validation = ValidateIngredientRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        var entity = new Ingredients
        {
            Name = request.Name!.Trim(),
            Unit = request.Unit!.Trim(),
            CurrentStock = request.CurrentStock!.Value,
            ReorderLevel = request.ReorderLevel!.Value,
            IsActive = request.IsActive ?? true
        };

        _db.Ingredients.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Created.", ingredientId = entity.IngredientID });
    }

    [HttpPut("ingredients/{ingredientId:int}")]
    public async Task<ActionResult> UpdateIngredient(
        int ingredientId,
        [FromBody] AdminUpsertIngredientRequest request,
        CancellationToken cancellationToken = default)
    {
        var entity = await _db.Ingredients.FirstOrDefaultAsync(i => i.IngredientID == ingredientId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Ingredient not found." });
        }

        var validation = ValidateIngredientRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        entity.Name = request.Name!.Trim();
        entity.Unit = request.Unit!.Trim();
        entity.CurrentStock = request.CurrentStock!.Value;
        entity.ReorderLevel = request.ReorderLevel!.Value;
        entity.IsActive = request.IsActive ?? true;

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Updated." });
    }

    [HttpPost("ingredients/{ingredientId:int}/deactivate")]
    public async Task<IActionResult> DeactivateIngredient(int ingredientId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Ingredients.FirstOrDefaultAsync(i => i.IngredientID == ingredientId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Ingredient not found." });
        }

        entity.IsActive = false;
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Deactivated." });
    }

    [HttpGet("table-statuses")]
    public async Task<ActionResult<IReadOnlyList<TableStatusResponse>>> GetTableStatuses(CancellationToken cancellationToken = default)
    {
        var items = await _db.TableStatus
            .AsNoTracking()
            .OrderBy(s => s.StatusName)
            .Select(s => new TableStatusResponse(s.StatusID, s.StatusCode, s.StatusName))
            .ToListAsync(cancellationToken);
        return Ok(items);
    }

    [HttpGet("tables")]
    public async Task<ActionResult<PagedResponse<AdminTableResponse>>> GetTables(
        [FromQuery] int? branchId,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] bool includeInactive = true,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _db.DiningTables
            .AsNoTracking()
            .Include(t => t.Branch)
            .Include(t => t.Status)
            .AsQueryable();

        if (!includeInactive)
        {
            query = query.Where(t => (t.IsActive ?? false) == true);
        }

        if (branchId is > 0)
        {
            query = query.Where(t => t.BranchID == branchId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var key = search.Trim();
            query = query.Where(t =>
                (t.QRCode != null && t.QRCode.Contains(key)) ||
                t.TableID.ToString().Contains(key));
        }

        var totalItems = await query.CountAsync(cancellationToken);
        var totalPages = totalItems <= 0 ? 0 : (int)Math.Ceiling(totalItems / (double)pageSize);

        var items = await query
            .OrderBy(t => t.Branch.Name)
            .ThenBy(t => t.TableID)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(t => new AdminTableResponse(
                t.TableID,
                t.BranchID,
                t.Branch.Name,
                t.NumberOfSeats,
                t.QRCode,
                t.StatusID,
                t.Status.StatusCode,
                t.Status.StatusName,
                t.IsActive ?? false))
            .ToListAsync(cancellationToken);

        return Ok(new PagedResponse<AdminTableResponse>(page, pageSize, totalItems, totalPages, items));
    }

    [HttpGet("tables/{tableId:int}")]
    public async Task<ActionResult<AdminTableResponse>> GetTableById(int tableId, CancellationToken cancellationToken = default)
    {
        var table = await _db.DiningTables
            .AsNoTracking()
            .Include(t => t.Branch)
            .Include(t => t.Status)
            .Where(t => t.TableID == tableId)
            .Select(t => new AdminTableResponse(
                t.TableID,
                t.BranchID,
                t.Branch.Name,
                t.NumberOfSeats,
                t.QRCode,
                t.StatusID,
                t.Status.StatusCode,
                t.Status.StatusName,
                t.IsActive ?? false))
            .FirstOrDefaultAsync(cancellationToken);

        return table is null ? NotFound(new { message = "Table not found." }) : Ok(table);
    }

    [HttpPost("tables")]
    public async Task<ActionResult> CreateTable([FromBody] AdminUpsertTableRequest request, CancellationToken cancellationToken = default)
    {
        var validation = await ValidateTableRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        var statusId = request.StatusId ?? await _db.TableStatus
            .Where(s => s.StatusCode == "AVAILABLE")
            .Select(s => (int?)s.StatusID)
            .FirstOrDefaultAsync(cancellationToken)
            ?? await _db.TableStatus
                .OrderBy(s => s.StatusID)
                .Select(s => (int?)s.StatusID)
                .FirstOrDefaultAsync(cancellationToken)
            ?? 1;

        var entity = new DiningTables
        {
            BranchID = request.BranchId!.Value,
            NumberOfSeats = request.NumberOfSeats!.Value,
            StatusID = statusId,
            QRCode = string.IsNullOrWhiteSpace(request.QRCode) ? null : request.QRCode.Trim(),
            IsActive = request.IsActive ?? true,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now
        };

        _db.DiningTables.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(entity.QRCode))
        {
            entity.QRCode = $"BR{entity.BranchID}-TB{entity.TableID}";
            entity.UpdatedAt = DateTime.Now;
            await _db.SaveChangesAsync(cancellationToken);
        }

        return Ok(new { message = "Created.", tableId = entity.TableID });
    }

    [HttpPut("tables/{tableId:int}")]
    public async Task<ActionResult> UpdateTable(
        int tableId,
        [FromBody] AdminUpsertTableRequest request,
        CancellationToken cancellationToken = default)
    {
        var entity = await _db.DiningTables.FirstOrDefaultAsync(t => t.TableID == tableId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Table not found." });
        }

        var validation = await ValidateTableRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        entity.BranchID = request.BranchId!.Value;
        entity.NumberOfSeats = request.NumberOfSeats!.Value;
        entity.StatusID = request.StatusId ?? entity.StatusID;
        entity.QRCode = string.IsNullOrWhiteSpace(request.QRCode) ? $"BR{entity.BranchID}-TB{entity.TableID}" : request.QRCode.Trim();
        entity.IsActive = request.IsActive ?? true;
        entity.UpdatedAt = DateTime.Now;

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Updated." });
    }

    [HttpPost("tables/{tableId:int}/deactivate")]
    public async Task<IActionResult> DeactivateTable(int tableId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.DiningTables.FirstOrDefaultAsync(t => t.TableID == tableId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Table not found." });
        }

        entity.IsActive = false;
        entity.UpdatedAt = DateTime.Now;
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Deactivated." });
    }

    private async Task<ActionResult?> ValidateDishRequest(AdminUpsertDishRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new { message = "Name is required." });
        }

        if (request.Price is null || request.Price < 0)
        {
            return BadRequest(new { message = "Price is invalid." });
        }

        if (request.CategoryId is null || request.CategoryId <= 0)
        {
            return BadRequest(new { message = "Category is required." });
        }

        var categoryExists = await _db.Categories.AnyAsync(c => c.CategoryID == request.CategoryId && (c.IsActive ?? false), cancellationToken);
        if (!categoryExists)
        {
            return BadRequest(new { message = "Category is invalid." });
        }

        return null;
    }

    private static ActionResult? ValidateIngredientRequest(AdminUpsertIngredientRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return new BadRequestObjectResult(new { message = "Name is required." });
        }

        if (string.IsNullOrWhiteSpace(request.Unit))
        {
            return new BadRequestObjectResult(new { message = "Unit is required." });
        }

        if (request.CurrentStock is null || request.CurrentStock < 0)
        {
            return new BadRequestObjectResult(new { message = "CurrentStock is invalid." });
        }

        if (request.ReorderLevel is null || request.ReorderLevel < 0)
        {
            return new BadRequestObjectResult(new { message = "ReorderLevel is invalid." });
        }

        return null;
    }

    private async Task<ActionResult?> ValidateTableRequest(AdminUpsertTableRequest request, CancellationToken cancellationToken)
    {
        if (request.BranchId is null || request.BranchId <= 0)
        {
            return BadRequest(new { message = "Branch is required." });
        }

        var branchExists = await _db.Branches.AnyAsync(b => b.BranchID == request.BranchId && (b.IsActive ?? false), cancellationToken);
        if (!branchExists)
        {
            return BadRequest(new { message = "Branch is invalid." });
        }

        if (request.NumberOfSeats is null || request.NumberOfSeats <= 0)
        {
            return BadRequest(new { message = "NumberOfSeats is invalid." });
        }

        if (request.StatusId is > 0)
        {
            var statusExists = await _db.TableStatus.AnyAsync(s => s.StatusID == request.StatusId, cancellationToken);
            if (!statusExists)
            {
                return BadRequest(new { message = "Status is invalid." });
            }
        }

        return null;
    }

    public sealed record PagedResponse<T>(int Page, int PageSize, int TotalItems, int TotalPages, IReadOnlyList<T> Items);
    public sealed record AdminDishResponse(
        int DishId,
        string Name,
        decimal Price,
        int CategoryId,
        string CategoryName,
        string? Description,
        string? Unit,
        string? Image,
        bool IsVegetarian,
        bool IsDailySpecial,
        bool Available,
        bool IsActive);
    public sealed record AdminUpsertDishRequest(
        string? Name,
        decimal? Price,
        int? CategoryId,
        string? Description,
        string? Unit,
        string? Image,
        bool? IsVegetarian,
        bool? IsDailySpecial,
        bool? Available,
        bool? IsActive);
    public sealed record AdminDishIngredientLineResponse(
        int IngredientId,
        string Name,
        string Unit,
        decimal CurrentStock,
        bool IsActive,
        bool Selected,
        decimal QuantityPerDish);
    public sealed record UpdateDishIngredientsRequest(IReadOnlyList<UpdateDishIngredientItem>? Items);
    public sealed record UpdateDishIngredientItem(int IngredientId, decimal QuantityPerDish);

    public sealed record AdminIngredientResponse(
        int IngredientId,
        string Name,
        string Unit,
        decimal CurrentStock,
        decimal ReorderLevel,
        bool IsActive);
    public sealed record AdminUpsertIngredientRequest(
        string? Name,
        string? Unit,
        decimal? CurrentStock,
        decimal? ReorderLevel,
        bool? IsActive);

    public sealed record TableStatusResponse(int StatusId, string StatusCode, string StatusName);
    public sealed record AdminTableResponse(
        int TableId,
        int BranchId,
        string BranchName,
        int NumberOfSeats,
        string? QRCode,
        int StatusId,
        string StatusCode,
        string StatusName,
        bool IsActive);
    public sealed record AdminUpsertTableRequest(
        int? BranchId,
        int? NumberOfSeats,
        string? QRCode,
        int? StatusId,
        bool? IsActive);
}
