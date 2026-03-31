using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class AdminDishesIndexViewModel
{
    public IReadOnlyList<AdminDishDto> Items { get; init; } = Array.Empty<AdminDishDto>();
    public IReadOnlyList<CategoryDto> Categories { get; init; } = Array.Empty<CategoryDto>();
    public string? Search { get; init; }
    public int? CategoryId { get; init; }
    public int Page { get; init; }
    public int TotalPages { get; init; }
    public int TotalItems { get; init; }
}

public sealed class AdminDishFormViewModel
{
    public int? DishId { get; init; }
    public int? DishID => DishId;
    public string Name { get; init; } = "";
    public decimal? Price { get; init; }
    public int CategoryId { get; init; }
    public int CategoryID => CategoryId;
    public string? Description { get; init; }
    public string? Unit { get; init; }
    public string? Image { get; init; }
    public bool IsVegetarian { get; init; }
    public bool IsDailySpecial { get; init; }
    public bool Available { get; init; } = true;
    public bool IsActive { get; init; } = true;
    public IReadOnlyList<CategoryDto> Categories { get; init; } = Array.Empty<CategoryDto>();
}

public sealed class AdminDishIngredientsViewModel
{
    public int DishId { get; init; }
    public int DishID => DishId;
    public string DishName { get; init; } = "";
    public string Name => DishName;
    public IReadOnlyList<AdminDishIngredientLineDto> Lines { get; init; } = Array.Empty<AdminDishIngredientLineDto>();
    public IReadOnlyList<AdminDishIngredientLegacyViewModel> DishIngredients =>
        Lines
            .Where(x => x.Selected)
            .OrderBy(x => x.Name)
            .Select(x => new AdminDishIngredientLegacyViewModel(x))
            .ToArray();
}

public sealed class AdminDishIngredientLegacyViewModel
{
    public AdminDishIngredientLegacyViewModel(AdminDishIngredientLineDto line)
    {
        DishIngredientID = line.IngredientId;
        IngredientID = line.IngredientId;
        QuantityPerDish = line.QuantityPerDish;
        Ingredients = new AdminIngredientLegacyViewModel(line);
    }

    public int DishIngredientID { get; }
    public int IngredientID { get; }
    public decimal QuantityPerDish { get; }
    public AdminIngredientLegacyViewModel Ingredients { get; }
}

public sealed class AdminIngredientLegacyViewModel
{
    public AdminIngredientLegacyViewModel(AdminDishIngredientLineDto line)
    {
        IngredientID = line.IngredientId;
        Name = line.Name;
        Unit = line.Unit;
        CurrentStock = line.CurrentStock;
        IsActive = line.IsActive;
    }

    public int IngredientID { get; }
    public string Name { get; }
    public string Unit { get; }
    public decimal CurrentStock { get; }
    public bool IsActive { get; }
}

public sealed class AdminIngredientsIndexViewModel
{
    public IReadOnlyList<AdminIngredientDto> Items { get; init; } = Array.Empty<AdminIngredientDto>();
    public string? Search { get; init; }
    public bool? OnlyActive { get; init; }
    public int Page { get; init; }
    public int TotalPages { get; init; }
    public int TotalItems { get; init; }
}

public sealed class AdminIngredientFormViewModel
{
    public int? IngredientId { get; init; }
    public string Name { get; init; } = "";
    public string Unit { get; init; } = "";
    public decimal? CurrentStock { get; init; }
    public decimal? ReorderLevel { get; init; }
    public bool IsActive { get; init; } = true;
}

public sealed class AdminTablesIndexViewModel
{
    public IReadOnlyList<AdminTableDto> Items { get; init; } = Array.Empty<AdminTableDto>();
    public IReadOnlyList<BranchDto> Branches { get; init; } = Array.Empty<BranchDto>();
    public string? Search { get; init; }
    public int? BranchId { get; init; }
    public int Page { get; init; }
    public int TotalPages { get; init; }
    public int TotalItems { get; init; }
}

public sealed class AdminTableFormViewModel
{
    public int? TableId { get; init; }
    public int BranchId { get; init; }
    public int? NumberOfSeats { get; init; }
    public string? QRCode { get; init; }
    public int StatusId { get; init; }
    public bool IsActive { get; init; } = true;

    public IReadOnlyList<BranchDto> Branches { get; init; } = Array.Empty<BranchDto>();
    public IReadOnlyList<TableStatusDto> Statuses { get; init; } = Array.Empty<TableStatusDto>();
}
