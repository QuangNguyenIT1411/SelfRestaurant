namespace SelfRestaurant.Gateway.Mvc.Models;

public sealed class CustomerAuthPageViewModel
{
    public string Mode { get; set; } = "login";

    public CustomerLoginViewModel Login { get; set; } = new();

    public CustomerRegisterViewModel Register { get; set; } = new();
}
