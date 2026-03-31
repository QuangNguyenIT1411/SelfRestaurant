# Migration Gap Matrix (Legacy MVC vs Microservices)

## Legend

- `Done`: already running on microservices/gateway
- `Partial`: some endpoints/views exist, not complete
- `Missing`: not migrated yet

## Customer/Public

| Legacy MVC Module | Legacy Location | New Target | Status | Notes |
|---|---|---|---|---|
| Home (branches/tables) | `SelfRestaurant/Controllers/HomeController.cs` | `Gateway HomeController` + `Catalog API` | Done | Running |
| Menu + QR + add item | `SelfRestaurant/Controllers/MenuController.cs` | `Gateway MenuController` + `Catalog/Orders APIs` | Done | Running |
| Order summary/submit | `SelfRestaurant/Controllers/OrderController.cs` | `Gateway OrderController` + `Orders API` | Done | Running |
| Customer login/register/profile | `SelfRestaurant/Controllers/CustomerController.cs` | `Gateway CustomerController` + `Customers/Identity APIs` | Partial | Running with temporary customer API; full identity parity pending |

## Staff

| Legacy MVC Module | Legacy Location | New Target | Status | Notes |
|---|---|---|---|---|
| Staff Account login/forgot/reset | `SelfRestaurant/Areas/Staff/Controllers/AccountController.cs` | `Gateway Staff Area` + `Identity API` | Partial | Login/logout done; forgot/reset for staff not required in current UX |
| Chef queue/history | `SelfRestaurant/Areas/Staff/Controllers/HomeController.cs` (+ chef views) | `Gateway Staff Area` + `Orders API` | Done | Queue/history + status transitions done |
| Cashier checkout/history/report | `SelfRestaurant/Areas/Staff/Controllers/CashierController.cs` | `Gateway Staff Area` + `Billing API` | Done | Checkout/history/report + account update done |

## Admin

| Legacy MVC Module | Legacy Location | New Target | Status | Notes |
|---|---|---|---|---|
| Dashboard | `SelfRestaurant/Areas/Admin/Controllers/DashboardController.cs` | `Gateway Admin Dashboard` + `Identity/Orders stats APIs` | Partial | Basic screen exists |
| Categories | `SelfRestaurant/Areas/Admin/...` | `Gateway Admin Categories` + `Catalog API` | Partial | Basic CRUD exists |
| Dishes management | `SelfRestaurant/Areas/Admin/Controllers/DishesController.cs` | `Gateway Admin Dishes` + `Catalog API` | Done | CRUD + dish-ingredient mapping |
| Ingredients | `SelfRestaurant/Areas/Admin/Controllers/IngredientsController.cs` | `Gateway Admin Ingredients` + `Catalog/Inventory API` | Done | CRUD + deactivate |
| Employees | `SelfRestaurant/Areas/Admin/Controllers/EmployeesController.cs` | `Gateway Admin Employees` + `Identity API` | Done | CRUD + deactivate + filters |
| Customers admin | `SelfRestaurant/Areas/Admin/Controllers/CustomersController.cs` | `Gateway Admin Customers` + `Customers API` | Done | CRUD + deactivate + search/page |
| Reports | `SelfRestaurant/Areas/Admin/Controllers/ReportsController.cs` | `Gateway Admin Reports` + `Billing/Orders APIs` | Done | Revenue/top-dishes reports on Orders API |
| Settings | `SelfRestaurant/Areas/Admin/Controllers/SettingsController.cs` | `Gateway Admin Settings` + `Identity/Catalog APIs` | Done | Update profile + change password |
| Tables/QR | `SelfRestaurant/*` | `Gateway Admin Tables` + `Catalog API` | Done | CRUD tables + QR code + status |

## Technical Debt To Clear Early

- Corrupted files with NUL bytes in active paths.
- Incomplete/missing `Gateway` service clients/models and staff auth attribute.
- Corrupted `Identity` source file currently blocking full rebuild.
- SQL bootstrap scripts need single clean canonical version.

## Next Concrete Implementation Order

1. Identity rebuild (clean controller set + auth contracts).
2. Gateway staff account + authorization middleware/attribute.
3. Cashier UI wiring to Billing API.
4. Chef UI wiring to Orders API.
5. Admin modules one by one: Employees -> Ingredients -> Customers -> Reports -> Settings -> Dishes.
