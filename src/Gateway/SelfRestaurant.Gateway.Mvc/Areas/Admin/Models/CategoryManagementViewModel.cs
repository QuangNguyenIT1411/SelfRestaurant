namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class UnitSummaryViewModel
{
    public string Unit { get; set; } = "";
    public int DishCount { get; set; }
}

public sealed class CategoryItemViewModel
{
    public int CategoryID { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public int? DisplayOrder { get; set; }
    public bool? IsActive { get; set; }
}

public sealed class CategoryManagementViewModel
{
    public IList<UnitSummaryViewModel> Units { get; set; } = new List<UnitSummaryViewModel>();
    public IList<CategoryItemViewModel> Categories { get; set; } = new List<CategoryItemViewModel>();
}
