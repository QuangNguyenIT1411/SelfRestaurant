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
    private readonly SelfRestaurant.Catalog.Api.Infrastructure.Auditing.BusinessAuditLogger _auditLogger;

    public AdminCatalogController(CatalogDbContext db, SelfRestaurant.Catalog.Api.Infrastructure.Auditing.BusinessAuditLogger auditLogger)
    {
        _db = db;
        _auditLogger = auditLogger;
    }

    [HttpGet("dishes")]
    public async Task<ActionResult<PagedResponse<AdminDishResponse>>> GetDishes(
        [FromQuery] string? search,
        [FromQuery] int? categoryId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] bool includeInactive = true,
        [FromQuery] bool vegetarianOnly = false,
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

        if (vegetarianOnly)
        {
            query = query.Where(d => (d.IsVegetarian ?? false) == true);
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

        return dish is null ? NotFound(new { message = "Không tìm thấy món ăn." }) : Ok(dish);
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
        _auditLogger.Add(
            actionType: "DISH_CREATED",
            entityType: "DISH",
            entityId: entity.DishID.ToString(),
            dishId: entity.DishID,
            beforeState: null,
            afterState: new
            {
                entity.Name,
                entity.Price,
                entity.CategoryID,
                entity.Available,
                entity.IsActive
            });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã tạo món ăn.", dishId = entity.DishID });
    }

    [HttpPost("branches/{branchId:int}/chef/dishes")]
    public async Task<ActionResult<ChefDishMutationResponse>> CreateChefDishForBranch(
        int branchId,
        [FromBody] AdminUpsertDishRequest request,
        CancellationToken cancellationToken = default)
    {
        var branchExists = await _db.Branches.AnyAsync(
            b => b.BranchID == branchId && (b.IsActive ?? false),
            cancellationToken);
        if (!branchExists)
        {
            return BadRequest(new { message = "Chi nhánh không hợp lệ." });
        }

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
        _auditLogger.Add(
            actionType: "DISH_CREATED_FOR_BRANCH",
            entityType: "DISH",
            entityId: entity.DishID.ToString(),
            dishId: entity.DishID,
            beforeState: null,
            afterState: new
            {
                branchId,
                entity.Name,
                entity.Price,
                entity.CategoryID,
                entity.Available,
                entity.IsActive
            });
        await _db.SaveChangesAsync(cancellationToken);

        var todayMenu = await EnsureTodayMenuAsync(branchId, cancellationToken);
        var menuCategory = await EnsureMenuCategoryAsync(todayMenu.MenuID, entity.CategoryID, cancellationToken);
        await EnsureCategoryDishAsync(menuCategory.MenuCategoryID, entity.DishID, entity.Available ?? true, cancellationToken);

        return Ok(new ChefDishMutationResponse(entity.DishID, "Created and attached to today's menu."));
    }

    [HttpPut("branches/{branchId:int}/chef/dishes/{dishId:int}")]
    public async Task<ActionResult<ChefDishMutationResponse>> UpdateChefDishForBranch(
        int branchId,
        int dishId,
        [FromBody] AdminUpsertDishRequest request,
        CancellationToken cancellationToken = default)
    {
        var branchExists = await _db.Branches.AnyAsync(
            b => b.BranchID == branchId && (b.IsActive ?? false),
            cancellationToken);
        if (!branchExists)
        {
            return BadRequest(new { message = "Chi nhánh không hợp lệ." });
        }

        var entity = await _db.Dishes.FirstOrDefaultAsync(d => d.DishID == dishId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Không tìm thấy món ăn." });
        }

        var validation = await ValidateDishRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        var beforeAudit = new
        {
            entity.Name,
            entity.Price,
            entity.CategoryID,
            entity.Available,
            entity.IsActive
        };

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
        _auditLogger.Add(
            actionType: "DISH_UPDATED_FOR_BRANCH",
            entityType: "DISH",
            entityId: entity.DishID.ToString(),
            dishId: entity.DishID,
            beforeState: beforeAudit,
            afterState: new
            {
                request.Name,
                request.Price,
                request.CategoryId,
                entity.Available,
                entity.IsActive,
                branchId
            });

        var todayMenu = await EnsureTodayMenuAsync(branchId, cancellationToken);
        var targetCategory = await EnsureMenuCategoryAsync(todayMenu.MenuID, entity.CategoryID, cancellationToken);
        await EnsureCategoryDishAsync(targetCategory.MenuCategoryID, entity.DishID, entity.Available ?? true, cancellationToken);

        var staleLinks = await _db.CategoryDish
            .Include(cd => cd.MenuCategory)
            .Where(cd =>
                cd.DishID == entity.DishID &&
                cd.MenuCategory.MenuID == todayMenu.MenuID &&
                cd.MenuCategoryID != targetCategory.MenuCategoryID)
            .ToListAsync(cancellationToken);

        if (staleLinks.Count > 0)
        {
            _db.CategoryDish.RemoveRange(staleLinks);
        }

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new ChefDishMutationResponse(entity.DishID, "Updated and synced to today's menu."));
    }

    [HttpPut("dishes/{dishId:int}")]
    public async Task<ActionResult> UpdateDish(int dishId, [FromBody] AdminUpsertDishRequest request, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Dishes.FirstOrDefaultAsync(d => d.DishID == dishId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Không tìm thấy món ăn." });
        }

        var validation = await ValidateDishRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        var beforeAudit = new
        {
            entity.Name,
            entity.Price,
            entity.CategoryID,
            entity.Available,
            entity.IsActive
        };

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
        _auditLogger.Add(
            actionType: "DISH_UPDATED",
            entityType: "DISH",
            entityId: entity.DishID.ToString(),
            dishId: entity.DishID,
            beforeState: beforeAudit,
            afterState: new
            {
                request.Name,
                request.Price,
                request.CategoryId,
                entity.Available,
                entity.IsActive
            });

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã cập nhật món ăn." });
    }

    [HttpPost("dishes/{dishId:int}/deactivate")]
    public async Task<IActionResult> DeactivateDish(int dishId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Dishes.FirstOrDefaultAsync(d => d.DishID == dishId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Không tìm thấy món ăn." });
        }

        var beforeAudit = new { entity.IsActive, entity.Available };
        entity.IsActive = false;
        entity.Available = false;
        entity.UpdatedAt = DateTime.Now;
        _auditLogger.Add(
            actionType: "DISH_DEACTIVATED",
            entityType: "DISH",
            entityId: entity.DishID.ToString(),
            dishId: entity.DishID,
            beforeState: beforeAudit,
            afterState: new { isActive = false, available = false });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã vô hiệu món ăn." });
    }

    [HttpGet("dishes/{dishId:int}/ingredients")]
    public async Task<ActionResult<IReadOnlyList<AdminDishIngredientLineResponse>>> GetDishIngredients(int dishId, CancellationToken cancellationToken = default)
    {
        var dishExists = await _db.Dishes.AnyAsync(d => d.DishID == dishId, cancellationToken);
        if (!dishExists)
        {
            return NotFound(new { message = "Không tìm thấy món ăn." });
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
            return NotFound(new { message = "Không tìm thấy món ăn." });
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
                return BadRequest(new { message = "Có nguyên liệu không hợp lệ." });
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

        _auditLogger.Add(
            actionType: "DISH_INGREDIENTS_UPDATED",
            entityType: "DISH",
            entityId: dishId.ToString(),
            dishId: dishId,
            beforeState: new { ingredientCount = current.Count },
            afterState: new
            {
                ingredientCount = cleaned.Count,
                ingredientIds = cleaned.Select(x => x.IngredientId).ToArray()
            });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã cập nhật nguyên liệu món ăn." });
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

        return item is null ? NotFound(new { message = "Không tìm thấy nguyên liệu." }) : Ok(item);
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
        _auditLogger.Add(
            actionType: "INGREDIENT_CREATED",
            entityType: "INGREDIENT",
            entityId: entity.IngredientID.ToString(),
            beforeState: null,
            afterState: new
            {
                entity.Name,
                entity.Unit,
                entity.CurrentStock,
                entity.ReorderLevel,
                entity.IsActive
            });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã tạo nguyên liệu.", ingredientId = entity.IngredientID });
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
            return NotFound(new { message = "Không tìm thấy nguyên liệu." });
        }

        var validation = ValidateIngredientRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        var beforeAudit = new
        {
            entity.Name,
            entity.Unit,
            entity.CurrentStock,
            entity.ReorderLevel,
            entity.IsActive
        };

        entity.Name = request.Name!.Trim();
        entity.Unit = request.Unit!.Trim();
        entity.CurrentStock = request.CurrentStock!.Value;
        entity.ReorderLevel = request.ReorderLevel!.Value;
        entity.IsActive = request.IsActive ?? true;

        _auditLogger.Add(
            actionType: "INGREDIENT_UPDATED",
            entityType: "INGREDIENT",
            entityId: entity.IngredientID.ToString(),
            beforeState: beforeAudit,
            afterState: new
            {
                entity.Name,
                entity.Unit,
                entity.CurrentStock,
                entity.ReorderLevel,
                entity.IsActive
            });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã cập nhật nguyên liệu." });
    }

    [HttpPost("ingredients/{ingredientId:int}/deactivate")]
    public async Task<IActionResult> DeactivateIngredient(int ingredientId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Ingredients.FirstOrDefaultAsync(i => i.IngredientID == ingredientId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Không tìm thấy nguyên liệu." });
        }

        var beforeAudit = new { entity.IsActive };
        entity.IsActive = false;
        _auditLogger.Add(
            actionType: "INGREDIENT_DEACTIVATED",
            entityType: "INGREDIENT",
            entityId: entity.IngredientID.ToString(),
            beforeState: beforeAudit,
            afterState: new { isActive = false });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã vô hiệu nguyên liệu." });
    }

    [HttpDelete("ingredients/{ingredientId:int}")]
    public async Task<IActionResult> DeleteIngredient(int ingredientId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Ingredients
            .Include(i => i.DishIngredients)
            .FirstOrDefaultAsync(i => i.IngredientID == ingredientId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Không tìm thấy nguyên liệu." });
        }

        if (entity.DishIngredients.Count > 0)
        {
            return Conflict(new
            {
                message = "Nguyên liệu đang được dùng trong công thức món ăn. Hãy dùng 'Vô hiệu' nếu bạn muốn ngừng sử dụng."
            });
        }

        var beforeAudit = new
        {
            entity.Name,
            entity.Unit,
            entity.CurrentStock,
            entity.ReorderLevel,
            entity.IsActive
        };

        _db.Ingredients.Remove(entity);
        _auditLogger.Add(
            actionType: "INGREDIENT_DELETED",
            entityType: "INGREDIENT",
            entityId: entity.IngredientID.ToString(),
            beforeState: beforeAudit,
            afterState: null);
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã xóa nguyên liệu." });
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
                t.TableID.ToString().Contains(key) ||
                t.NumberOfSeats.ToString().Contains(key) ||
                t.Branch.Name.Contains(key) ||
                t.Status.StatusName.Contains(key));
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

        return table is null ? NotFound(new { message = "Không tìm thấy bàn." }) : Ok(table);
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
        _auditLogger.Add(
            actionType: "TABLE_CREATED",
            entityType: "TABLE",
            entityId: entity.TableID.ToString(),
            tableId: entity.TableID,
            beforeState: null,
            afterState: new
            {
                entity.BranchID,
                entity.NumberOfSeats,
                entity.StatusID,
                entity.QRCode,
                entity.IsActive
            });
        await _db.SaveChangesAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(entity.QRCode))
        {
            entity.QRCode = $"BR{entity.BranchID}-TB{entity.TableID}";
            entity.UpdatedAt = DateTime.Now;
            await _db.SaveChangesAsync(cancellationToken);
        }

        return Ok(new { message = "Đã tạo bàn.", tableId = entity.TableID });
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
            return NotFound(new { message = "Không tìm thấy bàn." });
        }

        var validation = await ValidateTableRequest(request, cancellationToken);
        if (validation is not null)
        {
            return validation;
        }

        var beforeAudit = new
        {
            entity.BranchID,
            entity.NumberOfSeats,
            entity.StatusID,
            entity.QRCode,
            entity.IsActive
        };

        entity.BranchID = request.BranchId!.Value;
        entity.NumberOfSeats = request.NumberOfSeats!.Value;
        entity.StatusID = request.StatusId ?? entity.StatusID;
        entity.QRCode = string.IsNullOrWhiteSpace(request.QRCode) ? $"BR{entity.BranchID}-TB{entity.TableID}" : request.QRCode.Trim();
        entity.IsActive = request.IsActive ?? true;
        entity.UpdatedAt = DateTime.Now;

        _auditLogger.Add(
            actionType: "TABLE_UPDATED",
            entityType: "TABLE",
            entityId: entity.TableID.ToString(),
            tableId: entity.TableID,
            beforeState: beforeAudit,
            afterState: new
            {
                entity.BranchID,
                entity.NumberOfSeats,
                entity.StatusID,
                entity.QRCode,
                entity.IsActive
            });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã cập nhật bàn." });
    }

    [HttpPost("tables/{tableId:int}/deactivate")]
    public async Task<IActionResult> DeactivateTable(int tableId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.DiningTables.FirstOrDefaultAsync(t => t.TableID == tableId, cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Không tìm thấy bàn." });
        }

        var beforeAudit = new { entity.IsActive, entity.StatusID };
        entity.IsActive = false;
        entity.UpdatedAt = DateTime.Now;
        _auditLogger.Add(
            actionType: "TABLE_DEACTIVATED",
            entityType: "TABLE",
            entityId: entity.TableID.ToString(),
            tableId: entity.TableID,
            beforeState: beforeAudit,
            afterState: new { isActive = false, entity.StatusID });
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Đã vô hiệu bàn." });
    }

    [HttpGet("internal/audit-logs")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetAuditLogs(
        [FromQuery] string? entityType,
        [FromQuery] string? entityId,
        [FromQuery] int? dishId,
        [FromQuery] int? tableId,
        [FromQuery] int take = 100,
        CancellationToken cancellationToken = default)
    {
        take = Math.Clamp(take, 1, 200);
        var query = _db.BusinessAuditLogs.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(entityType))
        {
            query = query.Where(x => x.EntityType == entityType.Trim());
        }

        if (!string.IsNullOrWhiteSpace(entityId))
        {
            query = query.Where(x => x.EntityId == entityId.Trim());
        }

        if (dishId is > 0)
        {
            query = query.Where(x => x.DishId == dishId.Value);
        }

        if (tableId is > 0)
        {
            query = query.Where(x => x.TableId == tableId.Value);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(take)
            .Select(x => new
            {
                auditId = x.BusinessAuditLogId,
                timestampUtc = x.CreatedAtUtc,
                actorType = x.ActorType,
                actorId = x.ActorId,
                actorCode = x.ActorCode,
                actorName = x.ActorName,
                actorRoleCode = x.ActorRoleCode,
                actionType = x.ActionType,
                entityType = x.EntityType,
                entityId = x.EntityId,
                tableId = x.TableId,
                orderId = x.OrderId,
                orderItemId = x.OrderItemId,
                dishId = x.DishId,
                billId = x.BillId,
                diningSessionCode = x.DiningSessionCode,
                correlationId = x.CorrelationId,
                idempotencyKey = x.IdempotencyKey,
                notes = x.Notes,
                beforeState = x.BeforeState,
                afterState = x.AfterState
            })
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    private async Task<ActionResult?> ValidateDishRequest(AdminUpsertDishRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new { message = "Tên món không được để trống." });
        }

        if (request.Price is null || request.Price < 0)
        {
            return BadRequest(new { message = "Giá bán không hợp lệ." });
        }

        if (request.CategoryId is null || request.CategoryId <= 0)
        {
            return BadRequest(new { message = "Vui lòng chọn danh mục." });
        }

        var categoryExists = await _db.Categories.AnyAsync(c => c.CategoryID == request.CategoryId && (c.IsActive ?? false), cancellationToken);
        if (!categoryExists)
        {
            return BadRequest(new { message = "Danh mục không hợp lệ." });
        }

        return null;
    }

    private async Task<Menus> EnsureTodayMenuAsync(int branchId, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.Today);
        var latestMenu = await _db.Menus
            .Where(m => m.BranchID == branchId && (m.IsActive ?? true))
            .OrderByDescending(m => m.Date)
            .ThenByDescending(m => m.MenuID)
            .FirstOrDefaultAsync(cancellationToken);

        if (latestMenu is not null && latestMenu.Date == today)
        {
            await BackfillMenuFromPreviousAsync(latestMenu, cancellationToken);
            return latestMenu;
        }

        var branchName = await _db.Branches
            .Where(b => b.BranchID == branchId)
            .Select(b => b.Name)
            .FirstOrDefaultAsync(cancellationToken) ?? $"Chi nhánh {branchId}";

        var menu = new Menus
        {
            MenuName = $"Thực đơn {branchName} - {today:dd/MM/yyyy}",
            Date = today,
            IsActive = true,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now,
            BranchID = branchId
        };

        _db.Menus.Add(menu);
        await _db.SaveChangesAsync(cancellationToken);
        await BackfillMenuFromPreviousAsync(menu, cancellationToken);
        return menu;
    }

    private async Task BackfillMenuFromPreviousAsync(Menus targetMenu, CancellationToken cancellationToken)
    {
        var previousMenu = await _db.Menus
            .AsNoTracking()
            .Where(m => m.BranchID == targetMenu.BranchID
                && (m.IsActive ?? true)
                && m.MenuID != targetMenu.MenuID
                && (m.Date == null || m.Date <= targetMenu.Date))
            .OrderByDescending(m => m.Date)
            .ThenByDescending(m => m.MenuID)
            .FirstOrDefaultAsync(cancellationToken);

        if (previousMenu is null)
        {
            return;
        }

        var previousCategories = await _db.MenuCategory
            .AsNoTracking()
            .Where(mc => mc.MenuID == previousMenu.MenuID && (mc.IsActive ?? true))
            .Select(mc => new
            {
                mc.CategoryID,
                Dishes = mc.CategoryDish
                    .Where(cd => cd.IsAvailable ?? true)
                    .Select(cd => new
                    {
                        cd.DishID,
                        cd.DisplayOrder,
                        IsAvailable = cd.IsAvailable ?? true
                    })
                    .ToList()
            })
            .ToListAsync(cancellationToken);

        foreach (var category in previousCategories)
        {
            var targetCategory = await EnsureMenuCategoryAsync(targetMenu.MenuID, category.CategoryID, cancellationToken);
            foreach (var dish in category.Dishes.OrderBy(x => x.DisplayOrder))
            {
                await EnsureCategoryDishAsync(targetCategory.MenuCategoryID, dish.DishID, dish.IsAvailable, cancellationToken);
            }
        }
    }

    private async Task<MenuCategory> EnsureMenuCategoryAsync(int menuId, int categoryId, CancellationToken cancellationToken)
    {
        var existing = await _db.MenuCategory
            .FirstOrDefaultAsync(mc => mc.MenuID == menuId && mc.CategoryID == categoryId, cancellationToken);
        if (existing is not null)
        {
            existing.IsActive = true;
            existing.UpdatedAt = DateTime.Now;
            await _db.SaveChangesAsync(cancellationToken);
            return existing;
        }

        var menuCategory = new MenuCategory
        {
            MenuID = menuId,
            CategoryID = categoryId,
            IsActive = true,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now
        };

        _db.MenuCategory.Add(menuCategory);
        await _db.SaveChangesAsync(cancellationToken);
        return menuCategory;
    }

    private async Task EnsureCategoryDishAsync(int menuCategoryId, int dishId, bool isAvailable, CancellationToken cancellationToken)
    {
        var existing = await _db.CategoryDish
            .FirstOrDefaultAsync(cd => cd.MenuCategoryID == menuCategoryId && cd.DishID == dishId, cancellationToken);
        if (existing is not null)
        {
            existing.IsAvailable = isAvailable;
            existing.UpdatedAt = DateTime.Now;
            await _db.SaveChangesAsync(cancellationToken);
            return;
        }

        var maxDisplayOrder = await _db.CategoryDish
            .Where(cd => cd.MenuCategoryID == menuCategoryId)
            .MaxAsync(cd => (int?)cd.DisplayOrder, cancellationToken) ?? 0;

        _db.CategoryDish.Add(new CategoryDish
        {
            MenuCategoryID = menuCategoryId,
            DishID = dishId,
            DisplayOrder = maxDisplayOrder + 1,
            IsAvailable = isAvailable,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now
        });

        await _db.SaveChangesAsync(cancellationToken);
    }

    private static ActionResult? ValidateIngredientRequest(AdminUpsertIngredientRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return new BadRequestObjectResult(new { message = "Tên nguyên liệu không được để trống." });
        }

        if (string.IsNullOrWhiteSpace(request.Unit))
        {
            return new BadRequestObjectResult(new { message = "Đơn vị không được để trống." });
        }

        if (request.CurrentStock is null || request.CurrentStock < 0)
        {
            return new BadRequestObjectResult(new { message = "Tồn kho không hợp lệ." });
        }

        if (request.ReorderLevel is null || request.ReorderLevel < 0)
        {
            return new BadRequestObjectResult(new { message = "Mức cảnh báo không hợp lệ." });
        }

        return null;
    }

    private async Task<ActionResult?> ValidateTableRequest(AdminUpsertTableRequest request, CancellationToken cancellationToken)
    {
        if (request.BranchId is null || request.BranchId <= 0)
        {
            return BadRequest(new { message = "Vui lòng chọn chi nhánh." });
        }

        var branchExists = await _db.Branches.AnyAsync(b => b.BranchID == request.BranchId && (b.IsActive ?? false), cancellationToken);
        if (!branchExists)
        {
            return BadRequest(new { message = "Chi nhánh không hợp lệ." });
        }

        if (request.NumberOfSeats is null || request.NumberOfSeats <= 0)
        {
            return BadRequest(new { message = "Số ghế không hợp lệ." });
        }

        if (request.StatusId is > 0)
        {
            var statusExists = await _db.TableStatus.AnyAsync(s => s.StatusID == request.StatusId, cancellationToken);
            if (!statusExists)
            {
                return BadRequest(new { message = "Trạng thái bàn không hợp lệ." });
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
    public sealed record ChefDishMutationResponse(int DishId, string Message);
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
