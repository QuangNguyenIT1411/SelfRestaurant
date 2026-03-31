var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options => options.IncludeScopes = true);

// Add services to the container.
builder.Services
    .AddControllersWithViews()
    .AddJsonOptions(options =>
    {
        // Keep MVC JSON keys in PascalCase to stay compatible with legacy scripts.
        options.JsonSerializerOptions.PropertyNamingPolicy = null;
        options.JsonSerializerOptions.DictionaryKeyPolicy = null;
    });

builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.IdleTimeout = TimeSpan.FromHours(8);
});

builder.Services.AddHttpContextAccessor();
builder.Services.AddTransient<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();
var serviceTimeout = TimeSpan.FromSeconds(Math.Clamp(builder.Configuration.GetValue<int?>("Services:TimeoutSeconds") ?? 10, 2, 60));

builder.Services.AddHttpClient<SelfRestaurant.Gateway.Mvc.Services.CatalogClient>(http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Catalog"] ?? "http://localhost:5101");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

builder.Services.AddHttpClient<SelfRestaurant.Gateway.Mvc.Services.OrdersClient>(http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Orders"] ?? "http://localhost:5102");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

builder.Services.AddHttpClient<SelfRestaurant.Gateway.Mvc.Services.CustomersClient>(http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Customers"] ?? "http://localhost:5103");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

builder.Services.AddHttpClient<SelfRestaurant.Gateway.Mvc.Services.IdentityClient>(http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Identity"] ?? "http://localhost:5104");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

builder.Services.AddHttpClient("IdentityFallbackCustomers", http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Customers"] ?? "http://localhost:5103");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

builder.Services.AddHttpClient("CustomersFallbackIdentity", http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Identity"] ?? "http://localhost:5104");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

builder.Services.AddHttpClient<SelfRestaurant.Gateway.Mvc.Services.BillingClient>(http =>
{
    http.BaseAddress = new Uri(builder.Configuration["Services:Billing"] ?? "http://localhost:5105");
    http.Timeout = serviceTimeout;
}).AddHttpMessageHandler<SelfRestaurant.Gateway.Mvc.Infrastructure.CorrelationIdHandler>();

var app = builder.Build();

app.Use(async (context, next) =>
{
    var correlationId = context.Request.Headers["X-Correlation-Id"].FirstOrDefault();
    if (string.IsNullOrWhiteSpace(correlationId))
    {
        correlationId = Guid.NewGuid().ToString("N");
    }

    context.Response.Headers["X-Correlation-Id"] = correlationId;

    using (app.Logger.BeginScope(new Dictionary<string, object> { ["correlationId"] = correlationId }))
    {
        await next();
    }
});

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

if (app.Configuration.GetValue<bool?>("HttpsRedirection:Enabled") ?? app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}
app.UseStaticFiles();

app.UseRouting();

app.UseSession();
app.UseAuthorization();

app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");

app.MapControllerRoute(
    name: "admin_tablesqr_compat",
    pattern: "Admin/TablesQR/{action=Index}/{id?}",
    defaults: new { area = "Admin", controller = "Tables" });

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));
app.MapGet("/readyz", () => Results.Ok(new { status = "ready" }));

app.Run();
