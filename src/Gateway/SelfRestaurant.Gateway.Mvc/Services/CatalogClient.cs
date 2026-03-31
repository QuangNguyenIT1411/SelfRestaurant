using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Services;

public sealed class CatalogClient : ApiClientBase
{
    public CatalogClient(HttpClient http) : base(http)
    {
    }

    public Task<IReadOnlyList<BranchDto>?> GetBranchesAsync(CancellationToken cancellationToken) =>
        GetAsync<IReadOnlyList<BranchDto>>("/api/branches", cancellationToken);

    public Task<BranchTablesResponse?> GetBranchTablesAsync(int branchId, CancellationToken cancellationToken) =>
        GetAsync<BranchTablesResponse>($"/api/branches/{branchId}/tables", cancellationToken);

    public Task<MenuResponse?> GetMenuAsync(int branchId, DateOnly? date = null, CancellationToken cancellationToken = default)
    {
        var query = date is null ? "" : $"?date={date:yyyy-MM-dd}";
        return GetAsync<MenuResponse>($"/api/branches/{branchId}/menu{query}", cancellationToken);
    }

    public Task<IReadOnlyList<CategoryDto>?> GetCategoriesAsync(bool includeInactive, CancellationToken cancellationToken)
    {
        var flag = includeInactive ? "true" : "false";
        return GetAsync<IReadOnlyList<CategoryDto>>($"/api/categories?includeInactive={flag}", cancellationToken);
    }

    public Task CreateCategoryAsync(CreateCategoryRequest request, CancellationToken cancellationToken) =>
        PostAsync("/api/categories", request, cancellationToken);

    public Task UpdateCategoryAsync(int categoryId, UpdateCategoryRequest request, CancellationToken cancellationToken) =>
        PutAsync($"/api/categories/{categoryId}", request, cancellationToken);

    public Task DeleteCategoryAsync(int categoryId, CancellationToken cancellationToken) =>
        DeleteAsync($"/api/categories/{categoryId}", cancellationToken);

    public Task<BranchTableDto?> GetTableByQrAsync(string code, CancellationToken cancellationToken) =>
        GetAsync<BranchTableDto>($"/api/tables/qr/{Uri.EscapeDataString(code)}", cancellationToken);

    public Task<AdminDishPagedResponse?> GetAdminDishesAsync(
        string? search,
        int? categoryId,
        int page,
        int pageSize,
        bool includeInactive,
        CancellationToken cancellationToken)
    {
        var qs = new List<string>
        {
            $"page={Math.Max(1, page)}",
            $"pageSize={Math.Clamp(pageSize, 1, 100)}",
            $"includeInactive={(includeInactive ? "true" : "false")}",
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            qs.Add($"search={Uri.EscapeDataString(search.Trim())}");
        }
        if (categoryId is > 0)
        {
            qs.Add($"categoryId={categoryId.Value}");
        }

        return GetAsync<AdminDishPagedResponse>($"/api/admin/dishes?{string.Join("&", qs)}", cancellationToken);
    }

    public Task<AdminDishDto?> GetAdminDishByIdAsync(int dishId, CancellationToken cancellationToken) =>
        GetAsync<AdminDishDto>($"/api/admin/dishes/{dishId}", cancellationToken);

    public Task CreateAdminDishAsync(AdminUpsertDishRequest request, CancellationToken cancellationToken) =>
        PostAsync("/api/admin/dishes", request, cancellationToken);

    public Task UpdateAdminDishAsync(int dishId, AdminUpsertDishRequest request, CancellationToken cancellationToken) =>
        PutAsync($"/api/admin/dishes/{dishId}", request, cancellationToken);

    public Task DeactivateAdminDishAsync(int dishId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/admin/dishes/{dishId}/deactivate", new { }, cancellationToken);

    public async Task<IReadOnlyList<AdminDishIngredientLineDto>> GetDishIngredientsAsync(int dishId, CancellationToken cancellationToken)
    {
        var list = await GetAsync<IReadOnlyList<AdminDishIngredientLineDto>>($"/api/admin/dishes/{dishId}/ingredients", cancellationToken);
        return list ?? Array.Empty<AdminDishIngredientLineDto>();
    }

    public Task UpdateDishIngredientsAsync(int dishId, IReadOnlyList<AdminDishIngredientItemRequest> items, CancellationToken cancellationToken) =>
        PutAsync($"/api/admin/dishes/{dishId}/ingredients", new AdminUpdateDishIngredientsRequest(items), cancellationToken);

    public Task<AdminIngredientPagedResponse?> GetAdminIngredientsAsync(
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var qs = new List<string>
        {
            $"page={Math.Max(1, page)}",
            $"pageSize={Math.Clamp(pageSize, 1, 100)}",
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            qs.Add($"search={Uri.EscapeDataString(search.Trim())}");
        }

        return GetAsync<AdminIngredientPagedResponse>($"/api/admin/ingredients?{string.Join("&", qs)}", cancellationToken);
    }

    public Task<AdminIngredientDto?> GetAdminIngredientByIdAsync(int ingredientId, CancellationToken cancellationToken) =>
        GetAsync<AdminIngredientDto>($"/api/admin/ingredients/{ingredientId}", cancellationToken);

    public Task CreateAdminIngredientAsync(AdminUpsertIngredientRequest request, CancellationToken cancellationToken) =>
        PostAsync("/api/admin/ingredients", request, cancellationToken);

    public Task UpdateAdminIngredientAsync(int ingredientId, AdminUpsertIngredientRequest request, CancellationToken cancellationToken) =>
        PutAsync($"/api/admin/ingredients/{ingredientId}", request, cancellationToken);

    public Task DeactivateAdminIngredientAsync(int ingredientId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/admin/ingredients/{ingredientId}/deactivate", new { }, cancellationToken);

    public async Task<IReadOnlyList<TableStatusDto>> GetTableStatusesAsync(CancellationToken cancellationToken)
    {
        var list = await GetAsync<IReadOnlyList<TableStatusDto>>("/api/admin/table-statuses", cancellationToken);
        return list ?? Array.Empty<TableStatusDto>();
    }

    public Task<AdminTablePagedResponse?> GetAdminTablesAsync(
        int? branchId,
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var qs = new List<string>
        {
            $"page={Math.Max(1, page)}",
            $"pageSize={Math.Clamp(pageSize, 1, 100)}",
        };

        if (branchId is > 0)
        {
            qs.Add($"branchId={branchId.Value}");
        }
        if (!string.IsNullOrWhiteSpace(search))
        {
            qs.Add($"search={Uri.EscapeDataString(search.Trim())}");
        }

        return GetAsync<AdminTablePagedResponse>($"/api/admin/tables?{string.Join("&", qs)}", cancellationToken);
    }

    public Task<AdminTableDto?> GetAdminTableByIdAsync(int tableId, CancellationToken cancellationToken) =>
        GetAsync<AdminTableDto>($"/api/admin/tables/{tableId}", cancellationToken);

    public Task CreateAdminTableAsync(AdminUpsertTableRequest request, CancellationToken cancellationToken) =>
        PostAsync("/api/admin/tables", request, cancellationToken);

    public Task UpdateAdminTableAsync(int tableId, AdminUpsertTableRequest request, CancellationToken cancellationToken) =>
        PutAsync($"/api/admin/tables/{tableId}", request, cancellationToken);

    public Task DeactivateAdminTableAsync(int tableId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/admin/tables/{tableId}/deactivate", new { }, cancellationToken);
}
