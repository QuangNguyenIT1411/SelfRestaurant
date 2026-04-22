import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { AdminLayout } from "../components/AdminLayout";
import { adminApi } from "../lib/api";
import type {
  AdminCategoriesScreenDto,
  AdminDashboardDto,
  AdminDishDto,
  AdminDishIngredientLineDto,
  AdminDishesScreenDto,
  AdminIngredientsScreenDto,
  AdminReportsScreenDto,
  AdminTableDto,
  AdminTablesScreenDto,
  Paged,
  StaffSessionUserDto,
} from "../lib/types";

type Props = { onLogout: () => Promise<void> };
type SectionKey = "overview" | "categories" | "dishes" | "ingredients" | "tables" | "reports" | "settings";

const emptyCategoryForm = { name: "", description: "", displayOrder: "0" };
const emptyIngredientForm = { name: "", unit: "kg", currentStock: "0", reorderLevel: "0" };
const emptyTableForm = { branchId: "", numberOfSeats: "4", statusId: "" };
const emptyDishForm = {
  name: "",
  price: "10000",
  categoryId: "",
  description: "",
  unit: "dia",
  isVegetarian: false,
  isDailySpecial: false,
  available: true,
};
const DISH_PAGE_SIZE = 10;
const INGREDIENT_PAGE_SIZE = 10;
const TABLE_PAGE_SIZE = 10;

function formatDateTime(value?: string | null) {
  if (!value) return "Chưa cập nhật";
  return new Date(value).toLocaleString("vi-VN");
}

function buildQrTargetUrl(qrCode?: string | null) {
  if (!qrCode) return "";
  const encoded = encodeURIComponent(qrCode);
  if (typeof window === "undefined") {
    return `/Menu/FromQr?code=${encoded}`;
  }
  return `${window.location.origin}/Menu/FromQr?code=${encoded}`;
}

function buildQrImageUrl(qrCode?: string | null) {
  const targetUrl = buildQrTargetUrl(qrCode);
  return targetUrl
    ? `https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=${encodeURIComponent(targetUrl)}`
    : "";
}

function resolveSection(pathname: string): SectionKey {
  const normalized = pathname.toLowerCase();
  if (normalized.includes("/admin/categories")) return "categories";
  if (normalized.includes("/admin/dishes")) return "dishes";
  if (normalized.includes("/admin/ingredients")) return "ingredients";
  if (normalized.includes("/admin/tablesqr")) return "tables";
  if (normalized.includes("/admin/reports")) return "reports";
  if (normalized.includes("/admin/settings")) return "settings";
  return "overview";
}

function resolveHeading(pathname: string): { title: string; description: string } {
  const normalized = pathname.toLowerCase();
  if (normalized.includes("/admin/categories")) return { title: "Quản lý danh mục", description: "Quản lý danh mục và đơn vị món ăn." };
  if (normalized.includes("/admin/dishes")) return { title: "Quản lý món ăn", description: "Quản lý món ăn, hình ảnh và thành phần món ăn." };
  if (normalized.includes("/admin/ingredients")) return { title: "Quản lý nguyên liệu", description: "Quản lý nguyên liệu và tồn kho." };
  if (normalized.includes("/admin/tablesqr")) return { title: "Quản lý bàn & mã QR", description: "Quản lý bàn ăn và mã QR." };
  if (normalized.includes("/admin/reports/topdishes")) return { title: "Món ăn gọi nhiều", description: "Top món theo số lượng bán ra." };
  if (normalized.includes("/admin/reports")) return { title: "Báo cáo doanh thu", description: "Tổng quan doanh thu theo ngày và chi nhánh." };
  if (normalized.includes("/admin/settings")) return { title: "Cài đặt tài khoản", description: "Cập nhật thông tin cá nhân và mật khẩu." };
  return { title: "Tổng quan quản trị", description: "Tổng quan đơn hàng, nhân sự, bàn ăn và chi nhánh." };
}

async function pickDishImage(): Promise<File | null> {
  if (typeof window === "undefined") return null;
  return await new Promise<File | null>((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.onerror = () => resolve(null);
    input.click();
  });
}

function buildPageNumbers(totalPages: number) {
  return Array.from({ length: totalPages }, (_, index) => index + 1);
}

export function AdminConsolePage({ onLogout }: Props) {
  const location = useLocation();
  const navigate = useNavigate();

  const [staff, setStaff] = useState<StaffSessionUserDto | null>(null);
  const [dashboard, setDashboard] = useState<AdminDashboardDto | null>(null);
  const [categories, setCategories] = useState<AdminCategoriesScreenDto | null>(null);
  const [dishes, setDishes] = useState<AdminDishesScreenDto | null>(null);
  const [ingredients, setIngredients] = useState<AdminIngredientsScreenDto | null>(null);
  const [tablesData, setTablesData] = useState<AdminTablesScreenDto | null>(null);
  const [reports, setReports] = useState<AdminReportsScreenDto | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const [categoryForm, setCategoryForm] = useState(emptyCategoryForm);
  const [categoryEditForm, setCategoryEditForm] = useState({ categoryId: 0, name: "", description: "", displayOrder: "0", isActive: true });
  const [ingredientForm, setIngredientForm] = useState(emptyIngredientForm);
  const [ingredientEditForm, setIngredientEditForm] = useState({ ingredientId: 0, name: "", unit: "kg", currentStock: "0", reorderLevel: "0", isActive: true });
  const [tableForm, setTableForm] = useState(emptyTableForm);
  const [tableEditForm, setTableEditForm] = useState({ tableId: 0, branchId: "", numberOfSeats: "4", statusId: "", qrCode: "", isActive: true });
  const [dishForm, setDishForm] = useState(emptyDishForm);
  const [dishEditForm, setDishEditForm] = useState({ dishId: 0, name: "", price: "10000", categoryId: "", description: "", unit: "dia", image: "", isVegetarian: false, isDailySpecial: false, available: true, isActive: true });
  const [dishIngredientEditor, setDishIngredientEditor] = useState<{ dishId: number; dishName: string; items: AdminDishIngredientLineDto[] } | null>(null);
  const [settingsDraft, setSettingsDraft] = useState({ name: "", phone: "", email: "" });
  const [passwordEditor, setPasswordEditor] = useState({ currentPassword: "", newPassword: "", confirmPassword: "" });

  const [reportBranchFilter, setReportBranchFilter] = useState("ALL");
  const [tableBranchFilter, setTableBranchFilter] = useState("ALL");
  const [tableSearch, setTableSearch] = useState("");
  const [tablePage, setTablePage] = useState(1);
  const [dishSearch, setDishSearch] = useState("");
  const [dishCategoryFilter, setDishCategoryFilter] = useState("ALL");
  const [dishOnlyVegetarian, setDishOnlyVegetarian] = useState(false);
  const [dishPage, setDishPage] = useState(1);
  const [ingredientSearch, setIngredientSearch] = useState("");
  const [ingredientOnlyActive, setIngredientOnlyActive] = useState(false);
  const [ingredientPage, setIngredientPage] = useState(1);
  const [tableSummaryItems, setTableSummaryItems] = useState<AdminTableDto[]>([]);
  const [initialized, setInitialized] = useState(false);

  const section = resolveSection(location.pathname);
  const pageHeading = resolveHeading(location.pathname);
  const isCategoryCreatePage = location.pathname.toLowerCase().includes("/admin/categories/create");
  const isCategoryEditPage = location.pathname.toLowerCase().includes("/admin/categories/edit");
  const isDishCreatePage = location.pathname.toLowerCase().includes("/admin/dishes/create");
  const isDishEditPage = location.pathname.toLowerCase().includes("/admin/dishes/edit");
  const isDishIngredientsPage = location.pathname.toLowerCase().includes("/admin/dishes/ingredients");
  const isIngredientCreatePage = location.pathname.toLowerCase().includes("/admin/ingredients/create");
  const isIngredientEditPage = location.pathname.toLowerCase().includes("/admin/ingredients/edit");
  const isTableEditPage = location.pathname.toLowerCase().includes("/admin/tablesqr/edit");
  const isTableQrPage = location.pathname.toLowerCase().includes("/admin/tablesqr/qr");
  const isRevenuePage = location.pathname.toLowerCase().includes("/admin/reports/revenue");
  const isTopDishesPage = location.pathname.toLowerCase().includes("/admin/reports/topdishes");

  const reportBranchOptions = useMemo(() => {
    const rows = reports?.revenue.revenueByBranchDate ?? [];
    const map = new Map<string, { label: string; count: number }>();
    rows.forEach((row) => {
      const current = map.get(String(row.branchId));
      map.set(String(row.branchId), { label: row.branchName, count: (current?.count ?? 0) + 1 });
    });
    return [{ key: "ALL", label: "Tất cả", count: rows.length }, ...Array.from(map.entries()).map(([key, value]) => ({ key, label: value.label, count: value.count }))];
  }, [reports]);

  const filteredRevenueRows = useMemo(() => {
    const rows = reports?.revenue.revenueByBranchDate ?? [];
    return reportBranchFilter === "ALL" ? rows : rows.filter((row) => String(row.branchId) === reportBranchFilter);
  }, [reportBranchFilter, reports]);

  const filteredRevenueTotal = useMemo(() => filteredRevenueRows.reduce((sum, row) => sum + row.totalRevenue, 0), [filteredRevenueRows]);

  async function loadTableSummaryData() {
    const firstPage = await adminApi.getTables("", undefined, 1, 100);
    const items = [...firstPage.tables.items];
    if (firstPage.tables.totalPages > 1) {
      const extraPages = await Promise.all(
        buildPageNumbers(firstPage.tables.totalPages)
          .slice(1)
          .map((pageNumber) => adminApi.getTables("", undefined, pageNumber, 100)),
      );
      extraPages.forEach((pageResult) => items.push(...pageResult.tables.items));
    }
    setTableSummaryItems(items);
  }

  async function loadStaticData() {
    const [session, nextDashboard, nextCategories, nextReports] = await Promise.all([
      adminApi.getSession(),
      adminApi.getDashboard(),
      adminApi.getCategories(),
      adminApi.getReports(),
    ]);
    setStaff(session.staff ?? null);
    setDashboard(nextDashboard);
    setCategories(nextCategories);
    setReports(nextReports);
    setSettingsDraft({
      name: nextDashboard.settings.name,
      phone: nextDashboard.settings.phone ?? "",
      email: nextDashboard.settings.email ?? "",
    });
  }

  async function loadDishesData() {
    const nextDishes = await adminApi.getDishes(
      dishSearch,
      dishCategoryFilter !== "ALL" ? Number(dishCategoryFilter) : undefined,
      dishPage,
      DISH_PAGE_SIZE,
      false,
      dishOnlyVegetarian,
    );
    setDishes(nextDishes);
  }

  async function loadIngredientsData() {
    const nextIngredients = await adminApi.getIngredients(
      ingredientSearch,
      ingredientPage,
      INGREDIENT_PAGE_SIZE,
      !ingredientOnlyActive,
    );
    setIngredients(nextIngredients);
  }

  async function loadTablesPageData() {
    const nextTables = await adminApi.getTables(
      tableSearch,
      tableBranchFilter !== "ALL" ? Number(tableBranchFilter) : undefined,
      tablePage,
      TABLE_PAGE_SIZE,
    );
    setTablesData(nextTables);
  }

  async function loadAll(showSpinner = true) {
    if (showSpinner) {
      setLoading(true);
    }
    setError(null);
    try {
      await Promise.all([
        loadStaticData(),
        loadDishesData(),
        loadIngredientsData(),
        loadTablesPageData(),
        loadTableSummaryData(),
      ]);
      setInitialized(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể tải dữ liệu quản trị.");
    } finally {
      if (showSpinner) {
        setLoading(false);
      }
    }
  }

  useEffect(() => {
    void loadAll();
  }, []);

  useEffect(() => {
    if (!initialized) return;
    void loadDishesData().catch((err) => setError(err instanceof Error ? err.message : "Không thể tải danh sách món ăn."));
  }, [initialized, dishSearch, dishCategoryFilter, dishOnlyVegetarian, dishPage]);

  useEffect(() => {
    if (!initialized) return;
    void loadIngredientsData().catch((err) => setError(err instanceof Error ? err.message : "Không thể tải danh sách nguyên liệu."));
  }, [initialized, ingredientSearch, ingredientOnlyActive, ingredientPage]);

  useEffect(() => {
    if (!initialized) return;
    void loadTablesPageData().catch((err) => setError(err instanceof Error ? err.message : "Không thể tải danh sách bàn."));
  }, [initialized, tableSearch, tableBranchFilter, tablePage]);

  useEffect(() => {
    const flash = (location.state as { message?: string } | null)?.message;
    if (flash) {
      setMessage(flash);
      navigate(location.pathname + location.search, { replace: true, state: null });
    }
  }, [location.pathname, location.search, location.state, navigate]);

  useEffect(() => {
    if (tablesData && !tableForm.branchId) {
      setTableForm({
        branchId: String(tablesData.branches[0]?.branchId ?? ""),
        numberOfSeats: "4",
        statusId: String(tablesData.tableStatuses[0]?.statusId ?? ""),
      });
    }
  }, [tableForm.branchId, tablesData]);

  useEffect(() => {
    if (dishes && !dishForm.categoryId) {
      setDishForm((current) => ({ ...current, categoryId: String(dishes.categories[0]?.categoryId ?? "") }));
    }
  }, [dishForm.categoryId, dishes]);

  function showMessage(nextMessage: string) {
    setError(null);
    setMessage(nextMessage);
  }

  async function refreshAndShow(action: Promise<{ message?: string } | unknown>) {
    try {
      const response = await action as { message?: string };
      if (response?.message) showMessage(response.message);
      await loadAll();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể cập nhật dữ liệu.");
    }
  }

  function openCategoryEditPage(category: AdminCategoriesScreenDto["categories"][number]) {
    setCategoryEditForm({
      categoryId: category.categoryId,
      name: category.name,
      description: category.description ?? "",
      displayOrder: String(category.displayOrder),
      isActive: category.isActive,
    });
    navigate("/Admin/Categories/Edit");
  }

  function openIngredientEditPage(ingredient: AdminIngredientsScreenDto["ingredients"]["items"][number]) {
    setIngredientEditForm({
      ingredientId: ingredient.ingredientId,
      name: ingredient.name,
      unit: ingredient.unit,
      currentStock: String(ingredient.currentStock),
      reorderLevel: String(ingredient.reorderLevel),
      isActive: ingredient.isActive,
    });
    navigate("/Admin/Ingredients/Edit");
  }

  async function removeIngredient(ingredient: AdminIngredientsScreenDto["ingredients"]["items"][number]) {
    if (!window.confirm(`Bạn có chắc muốn gỡ nguyên liệu "${ingredient.name}" khỏi danh sách quản lý?`)) {
      return;
    }

    await refreshAndShow(adminApi.deleteIngredient(ingredient.ingredientId));

    if (ingredientEditForm.ingredientId === ingredient.ingredientId) {
      setIngredientEditForm({ ingredientId: 0, name: "", unit: "kg", currentStock: "0", reorderLevel: "0", isActive: true });
      navigate("/Admin/Ingredients/Index");
    }
  }

  function openTableEditPage(table: AdminTablesScreenDto["tables"]["items"][number]) {
    setTableEditForm({
      tableId: table.tableId,
      branchId: String(table.branchId),
      numberOfSeats: String(table.numberOfSeats),
      statusId: String(table.statusId),
      qrCode: table.qrCode ?? "",
      isActive: table.isActive,
    });
    navigate("/Admin/TablesQR/Edit");
  }

  function openDishEditPage(dish: AdminDishDto) {
    setDishEditForm({
      dishId: dish.dishId,
      name: dish.name,
      price: String(dish.price),
      categoryId: String(dish.categoryId),
      description: dish.description ?? "",
      unit: dish.unit ?? "dia",
      image: dish.image ?? "",
      isVegetarian: dish.isVegetarian,
      isDailySpecial: dish.isDailySpecial,
      available: dish.available,
      isActive: dish.isActive,
    });
    navigate("/Admin/Dishes/Edit");
  }

  async function openDishIngredients(dishId: number, dishName: string) {
    try {
      setError(null);
      const items = await adminApi.getDishIngredients(dishId);
      setDishIngredientEditor({ dishId, dishName, items });
      navigate("/Admin/Dishes/Ingredients");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể tải nguyên liệu món ăn.");
    }
  }

  async function saveDishIngredientsEditor() {
    if (!dishIngredientEditor) return;
    const items = dishIngredientEditor.items
      .filter((item) => item.selected)
      .map((item) => ({ ingredientId: item.ingredientId, quantityPerDish: item.quantityPerDish }));
    await refreshAndShow(adminApi.saveDishIngredients(dishIngredientEditor.dishId, items));
    setDishIngredientEditor(null);
  }

  async function saveSettings() {
    try {
      const next = await adminApi.updateSettings({
        name: settingsDraft.name.trim(),
        phone: settingsDraft.phone.trim(),
        email: settingsDraft.email.trim() || null,
      });
      setDashboard((current) => current ? { ...current, settings: next } : current);
      showMessage("Đã cập nhật thông tin tài khoản.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể cập nhật thông tin tài khoản.");
    }
  }

  async function savePasswordChange() {
    try {
      const response = await adminApi.changePassword(passwordEditor);
      setPasswordEditor({ currentPassword: "", newPassword: "", confirmPassword: "" });
      showMessage(response.message);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể đổi mật khẩu.");
    }
  }

  const overviewBranchStats = useMemo(() => {
    const items = tableSummaryItems;
    const occupiedTables = items.filter((table) => table.statusCode === "OCCUPIED").length;
    return {
      occupiedTables,
      availableTables: items.filter((table) => table.statusCode !== "OCCUPIED").length,
      averageSeats: items.length > 0 ? Math.round(items.reduce((sum, table) => sum + table.numberOfSeats, 0) / items.length) : 0,
    };
  }, [tableSummaryItems]);

  const visibleDishes = dishes?.dishes.items ?? [];
  const visibleIngredients = ingredients?.ingredients.items ?? [];
  const visibleTables = tablesData?.tables.items ?? [];

  function renderPagination<T>(paged: Paged<T>, currentPage: number, onPageChange: (page: number) => void, keyPrefix: string) {
    if (paged.totalPages <= 1) return null;
    return (
      <div className="button-row wrap admin-pagination">
        {buildPageNumbers(paged.totalPages).map((pageNumber) => (
          <button
            key={`${keyPrefix}-page-${pageNumber}`}
            className={pageNumber === currentPage ? "active-toggle" : "ghost"}
            onClick={() => onPageChange(pageNumber)}
          >
            {pageNumber}
          </button>
        ))}
      </div>
    );
  }

  if (loading) return <div className="screen-message">Đang tải khu quản trị...</div>;
  if (error && !dashboard) return <div className="screen-message error-box">{error}</div>;
  if (!dashboard || !categories || !dishes || !ingredients || !tablesData || !reports) return null;

  return (
    <AdminLayout
      title={pageHeading.title}
      description={pageHeading.description}
      staff={staff ?? dashboard.staff}
      onLogout={onLogout}
      onRefresh={loadAll}
      message={message}
      error={error}
    >
      {section === "overview" ? (
        <section className="panel-grid">
          <article className="panel">
            <div className="panel-head">
              <h2>Tổng quan hoạt động</h2>
              <span>{dashboard.staff.branchName}</span>
            </div>
            <div className="list-grid compact-grid">
              <div className="list-card"><strong>{dashboard.stats.activeEmployees}</strong><p>Nhân viên đang hoạt động</p></div>
              <div className="list-card"><strong>{dashboard.stats.pendingOrders}</strong><p>Đơn đang chờ/đang làm</p></div>
              <div className="list-card"><strong>{dashboard.categories.length}</strong><p>Danh mục món ăn</p></div>
              <div className="list-card"><strong>{dashboard.tableStatuses.length}</strong><p>Trạng thái bàn</p></div>
            </div>
            <div className="summary-chip-grid">
              <article className="summary-chip"><span className="eyebrow">Bàn đang sử dụng</span><strong>{overviewBranchStats.occupiedTables}</strong></article>
              <article className="summary-chip"><span className="eyebrow">Bàn còn trống</span><strong>{overviewBranchStats.availableTables}</strong></article>
              <article className="summary-chip"><span className="eyebrow">Sức chứa trung bình</span><strong>{overviewBranchStats.averageSeats}</strong></article>
              <article className="summary-chip"><span className="eyebrow">Doanh thu hôm nay</span><strong>{dashboard.stats.todayRevenue.toLocaleString("vi-VN")} đ</strong></article>
            </div>
          </article>

          <article className="panel">
            <div className="panel-head">
              <h2>Nhân viên gần đây</h2>
              <span>{dashboard.latestEmployees.length}</span>
            </div>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Tên</th>
                  <th>Vai trò</th>
                  <th>Chi nhánh</th>
                  <th>Tài khoản</th>
                </tr>
              </thead>
              <tbody>
                {dashboard.latestEmployees.map((employee) => (
                  <tr key={employee.employeeId}>
                    <td>{employee.name}</td>
                    <td>{employee.roleName}</td>
                    <td>{employee.branchName}</td>
                    <td>{employee.username}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </article>

          <article className="panel">
            <div className="panel-head">
              <h2>Chi nhánh</h2>
              <span>{dashboard.branches.length}</span>
            </div>
            <div className="list-grid compact-grid">
              {dashboard.branches.map((branch) => (
                <div key={branch.branchId} className="list-card">
                  <strong>{branch.name}</strong>
                  <p>{branch.location || "Chưa cập nhật địa chỉ"}</p>
                  <small>Chi nhánh #{branch.branchId}</small>
                </div>
              ))}
            </div>
          </article>
        </section>
      ) : null}

      {section === "categories" ? (
        <section className={isCategoryEditPage ? "panel" : "panel-grid admin-categories-grid"}>
          {!isCategoryEditPage ? (
            <article className="panel">
              <div className="panel-head">
                <h2>Đơn vị món ăn</h2>
                <span className="status-pill info">{categories.units.length} đơn vị</span>
              </div>
              <table className="data-table compact-table">
                <thead>
                  <tr>
                    <th>Đơn vị</th>
                    <th className="text-right">Số món</th>
                  </tr>
                </thead>
                <tbody>
                  {categories.units.length > 0 ? categories.units.map((unit) => (
                    <tr key={unit.unit}>
                      <td><strong>{unit.unit}</strong></td>
                      <td className="text-right">{unit.dishCount}</td>
                    </tr>
                  )) : (
                    <tr><td colSpan={2} className="text-right">Chưa có đơn vị nào.</td></tr>
                  )}
                </tbody>
              </table>
            </article>
          ) : null}

          <article className="panel">
            <div className="toolbar-card">
              <div>
                <strong>Quản lý danh mục món ăn</strong>
                <div className="muted">Quản lý danh mục và đơn vị món ăn.</div>
              </div>
              <div className="button-row wrap">
                {isCategoryEditPage ? <button className="ghost" onClick={() => navigate("/Admin/Categories/Index")}>Quay lại danh sách</button> : null}
                <button className={isCategoryCreatePage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Categories/Create")}>Thêm danh mục</button>
                <button className={isCategoryEditPage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Categories/Edit")}>Sửa danh mục</button>
              </div>
            </div>

            {!isCategoryEditPage ? (
              <div className="entry-form-card">
                <div className="entry-form-header"><div><strong>Thêm danh mục mới</strong><div className="muted">Nhập tên, mô tả và thứ tự hiển thị.</div></div></div>
                <div className="entry-form-grid">
                  <label>Tên danh mục<input value={categoryForm.name} onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })} /></label>
                  <label>Thứ tự hiển thị<input type="number" value={categoryForm.displayOrder} onChange={(e) => setCategoryForm({ ...categoryForm, displayOrder: e.target.value })} /></label>
                  <label className="full-span">Mô tả<textarea rows={3} value={categoryForm.description} onChange={(e) => setCategoryForm({ ...categoryForm, description: e.target.value })} /></label>
                </div>
                <div className="entry-form-actions">
                  <span className="muted">Nhập tên, mô tả và thứ tự hiển thị của danh mục.</span>
                  <button onClick={() => {
                    if (!categoryForm.name.trim()) {
                      setError("Tên danh mục không được để trống.");
                      return;
                    }
                    void refreshAndShow(adminApi.createCategory({
                      name: categoryForm.name.trim(),
                      description: categoryForm.description.trim(),
                      displayOrder: Number(categoryForm.displayOrder || "0"),
                    })).then(() => {
                      setCategoryForm(emptyCategoryForm);
                      if (isCategoryCreatePage) navigate("/Admin/Categories/Index");
                    });
                  }}>Thêm danh mục</button>
                </div>
              </div>
            ) : null}

            {(categoryEditForm.categoryId > 0 || isCategoryEditPage) ? (
              <div className="entry-form-card edit-form-card">
                <div className="entry-form-header">
                  <div><strong>Chỉnh sửa danh mục</strong><div className="muted">Cập nhật thông tin danh mục đang chọn.</div></div>
                  <button className="ghost" onClick={() => { setCategoryEditForm({ categoryId: 0, name: "", description: "", displayOrder: "0", isActive: true }); navigate("/Admin/Categories/Index"); }}>Đóng</button>
                </div>
                {categoryEditForm.categoryId === 0 ? (
                  <div className="empty-report history-empty-card">
                    <i className="bi bi-folder2-open" />
                    <strong>Chưa có danh mục đang chỉnh sửa</strong>
                    <div>Hãy chọn một danh mục từ danh sách để mở biểu mẫu chỉnh sửa.</div>
                  </div>
                ) : (
                  <>
                    <div className="entry-form-grid">
                      <label>Tên danh mục<input value={categoryEditForm.name} onChange={(e) => setCategoryEditForm({ ...categoryEditForm, name: e.target.value })} /></label>
                      <label>Thứ tự hiển thị<input type="number" value={categoryEditForm.displayOrder} onChange={(e) => setCategoryEditForm({ ...categoryEditForm, displayOrder: e.target.value })} /></label>
                      <label className="full-span">Mô tả<textarea rows={3} value={categoryEditForm.description} onChange={(e) => setCategoryEditForm({ ...categoryEditForm, description: e.target.value })} /></label>
                    </div>
                    <div className="filter-chip-row">
                      <button type="button" className={`ghost ${categoryEditForm.isActive ? "active-toggle" : ""}`} onClick={() => setCategoryEditForm({ ...categoryEditForm, isActive: !categoryEditForm.isActive })}>
                        {categoryEditForm.isActive ? "Hoạt động" : "Ngừng hoạt động"}
                      </button>
                    </div>
                    <div className="entry-form-actions">
                      <span className="muted">Biểu mẫu chỉnh sửa được tách riêng để giữ đúng luồng quản trị.</span>
                      <button onClick={() => {
                        if (!categoryEditForm.name.trim()) {
                          setError("Tên danh mục không được để trống.");
                          return;
                        }
                        void refreshAndShow(adminApi.updateCategory(categoryEditForm.categoryId, {
                          name: categoryEditForm.name.trim(),
                          description: categoryEditForm.description.trim(),
                          displayOrder: Number(categoryEditForm.displayOrder || "0"),
                          isActive: categoryEditForm.isActive,
                        })).then(() => {
                          setCategoryEditForm({ categoryId: 0, name: "", description: "", displayOrder: "0", isActive: true });
                          navigate("/Admin/Categories/Index");
                        });
                      }}>Lưu thay đổi</button>
                    </div>
                  </>
                )}
              </div>
            ) : null}

            {!isCategoryEditPage ? (
              <>
                <div className="panel-head"><h2>Danh mục món ăn</h2><span className="status-pill success">{categories.categories.length} danh mục</span></div>
                <table className="data-table">
                  <thead><tr><th>Tên danh mục</th><th>Mô tả</th><th>Thứ tự</th><th>Kích hoạt</th><th>Thao tác</th></tr></thead>
                  <tbody>
                    {categories.categories.length > 0 ? categories.categories.map((category) => (
                      <tr key={category.categoryId}>
                        <td><strong>{category.name}</strong></td>
                        <td>{category.description || "-"}</td>
                        <td>{category.displayOrder}</td>
                        <td>{category.isActive ? <span className="status-pill success">Đang dùng</span> : <span className="status-pill danger">Ngừng dùng</span>}</td>
                        <td>
                          <div className="button-row wrap">
                            <button className="ghost" onClick={() => openCategoryEditPage(category)}>Sửa</button>
                            <button className="danger" onClick={() => void refreshAndShow(adminApi.deleteCategory(category.categoryId))}>Xóa</button>
                          </div>
                        </td>
                      </tr>
                    )) : <tr><td colSpan={5} className="text-right">Chưa có danh mục nào.</td></tr>}
                  </tbody>
                </table>
              </>
            ) : null}
          </article>
        </section>
      ) : null}

      {section === "dishes" ? (
        <section className="panel">
          <div className="toolbar-card">
            <div><strong>Quản lý món ăn</strong><div className="muted">Quản lý món ăn, hình ảnh và thành phần món ăn.</div></div>
            <div className="button-row wrap">
              {(isDishCreatePage || isDishEditPage || isDishIngredientsPage) ? <button className="ghost" onClick={() => navigate("/Admin/Dishes/Index")}>Quay lại danh sách món ăn</button> : null}
              <button className={isDishCreatePage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Dishes/Create")}>Thêm món mới</button>
              <button className={isDishIngredientsPage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Dishes/Ingredients")}>Thành phần món ăn</button>
            </div>
          </div>

          {isDishCreatePage ? (
            <div className="entry-form-card">
              <div className="entry-form-header"><div><strong>Thêm món mới</strong><div className="muted">Nhập thông tin món ăn theo form tạo mới.</div></div><span className="status-pill info">Tạo mới</span></div>
              <div className="entry-form-grid">
                <label>Tên món<input value={dishForm.name} onChange={(e) => setDishForm({ ...dishForm, name: e.target.value })} /></label>
                <label>Giá bán<input type="number" value={dishForm.price} onChange={(e) => setDishForm({ ...dishForm, price: e.target.value })} /></label>
                <label>Danh mục<select value={dishForm.categoryId} onChange={(e) => setDishForm({ ...dishForm, categoryId: e.target.value })}>{dishes.categories.map((category) => <option key={category.categoryId} value={category.categoryId}>{category.name}</option>)}</select></label>
                <label>Đơn vị<input value={dishForm.unit} onChange={(e) => setDishForm({ ...dishForm, unit: e.target.value })} /></label>
                <label className="full-span">Mô tả<textarea rows={3} value={dishForm.description} onChange={(e) => setDishForm({ ...dishForm, description: e.target.value })} /></label>
              </div>
              <div className="filter-chip-row">
                <button type="button" className={`ghost ${dishForm.isVegetarian ? "active-toggle" : ""}`} onClick={() => setDishForm({ ...dishForm, isVegetarian: !dishForm.isVegetarian })}>Món chay</button>
                <button type="button" className={`ghost ${dishForm.isDailySpecial ? "active-toggle" : ""}`} onClick={() => setDishForm({ ...dishForm, isDailySpecial: !dishForm.isDailySpecial })}>Món trong ngày</button>
                <button type="button" className={`ghost ${dishForm.available ? "active-toggle" : ""}`} onClick={() => setDishForm({ ...dishForm, available: !dishForm.available })}>Đang bán</button>
              </div>
              <div className="entry-form-actions">
                <span className="muted">Nếu cần ảnh món, hệ thống sẽ hỏi chọn file sau khi bấm tạo.</span>
                <button onClick={() => {
                  if (!dishForm.name.trim() || !dishForm.categoryId) {
                    setError("Vui lòng nhập tên món và chọn danh mục.");
                    return;
                  }
                  const payload = {
                    name: dishForm.name.trim(),
                    price: Number(dishForm.price || "0"),
                    categoryId: Number(dishForm.categoryId),
                    description: dishForm.description.trim(),
                    unit: dishForm.unit.trim() || "dia",
                    image: null,
                    isVegetarian: dishForm.isVegetarian,
                    isDailySpecial: dishForm.isDailySpecial,
                    available: dishForm.available,
                    isActive: true,
                  };
                  void (async () => {
                    const imageFile = await pickDishImage();
                    await refreshAndShow(imageFile ? adminApi.createDishWithImage(payload, imageFile) : adminApi.createDish(payload));
                    setDishForm({ ...emptyDishForm, categoryId: String(dishes.categories[0]?.categoryId ?? "") });
                    navigate("/Admin/Dishes/Index");
                  })();
                }}>Thêm món</button>
              </div>
            </div>
          ) : null}

          {!isDishCreatePage && !isDishEditPage && !isDishIngredientsPage ? (
            <div className="inline-filter-card admin-filter-card">
              <div><strong>Bộ lọc món ăn</strong><div className="muted">Lọc theo tên, mô tả, danh mục và món chay.</div></div>
              <div className="admin-filter-form">
                <label className="admin-filter-field admin-filter-field-wide"><span>Tìm kiếm</span><input value={dishSearch} onChange={(e) => { setDishPage(1); setDishSearch(e.target.value); }} placeholder="Tìm theo tên hoặc mô tả..." /></label>
                <label className="admin-filter-field"><span>Danh mục</span><select value={dishCategoryFilter} onChange={(e) => { setDishPage(1); setDishCategoryFilter(e.target.value); }}><option value="ALL">Tất cả danh mục</option>{dishes.categories.map((category) => <option key={category.categoryId} value={category.categoryId}>{category.name}</option>)}</select></label>
                <label className="admin-filter-check"><input type="checkbox" checked={dishOnlyVegetarian} onChange={(e) => { setDishPage(1); setDishOnlyVegetarian(e.target.checked); }} /><span>Chỉ món chay</span></label>
              </div>
              <div className="admin-filter-actions"><button className="ghost" onClick={() => { setDishPage(1); setDishSearch(""); setDishCategoryFilter("ALL"); setDishOnlyVegetarian(false); }}>Xóa bộ lọc</button></div>
            </div>
          ) : null}

          {(dishEditForm.dishId > 0 || isDishEditPage) ? (
            <div className="entry-form-card edit-form-card">
              <div className="entry-form-header">
                <div><strong>Chỉnh sửa món ăn</strong><div className="muted">Cập nhật thông tin món ăn đang chọn.</div></div>
                <button className="ghost" onClick={() => { setDishEditForm({ dishId: 0, name: "", price: "10000", categoryId: "", description: "", unit: "dia", image: "", isVegetarian: false, isDailySpecial: false, available: true, isActive: true }); navigate("/Admin/Dishes/Index"); }}>Đóng</button>
              </div>
              {dishEditForm.dishId === 0 ? (
                <div className="empty-report history-empty-card">
                  <i className="bi bi-pencil-square" />
                  <strong>Chưa có món ăn đang chỉnh sửa</strong>
                  <div>Hãy quay về danh sách món ăn và chọn một món để sửa.</div>
                </div>
              ) : (
                <>
                  <div className="entry-form-grid">
                    <label>Tên món<input value={dishEditForm.name} onChange={(e) => setDishEditForm({ ...dishEditForm, name: e.target.value })} /></label>
                    <label>Giá bán<input type="number" value={dishEditForm.price} onChange={(e) => setDishEditForm({ ...dishEditForm, price: e.target.value })} /></label>
                    <label>Danh mục<select value={dishEditForm.categoryId} onChange={(e) => setDishEditForm({ ...dishEditForm, categoryId: e.target.value })}>{dishes.categories.map((category) => <option key={category.categoryId} value={category.categoryId}>{category.name}</option>)}</select></label>
                    <label>Đơn vị<input value={dishEditForm.unit} onChange={(e) => setDishEditForm({ ...dishEditForm, unit: e.target.value })} /></label>
                    <label className="full-span">Mô tả<textarea rows={3} value={dishEditForm.description} onChange={(e) => setDishEditForm({ ...dishEditForm, description: e.target.value })} /></label>
                  </div>
                  <div className="filter-chip-row">
                    <button type="button" className={`ghost ${dishEditForm.isVegetarian ? "active-toggle" : ""}`} onClick={() => setDishEditForm({ ...dishEditForm, isVegetarian: !dishEditForm.isVegetarian })}>Món chay</button>
                    <button type="button" className={`ghost ${dishEditForm.isDailySpecial ? "active-toggle" : ""}`} onClick={() => setDishEditForm({ ...dishEditForm, isDailySpecial: !dishEditForm.isDailySpecial })}>Món trong ngày</button>
                    <button type="button" className={`ghost ${dishEditForm.available ? "active-toggle" : ""}`} onClick={() => setDishEditForm({ ...dishEditForm, available: !dishEditForm.available })}>Đang bán</button>
                  </div>
                  <div className="entry-form-actions">
                    <span className="muted">Nếu muốn đổi ảnh, hệ thống sẽ hỏi chọn file mới khi lưu.</span>
                    <button onClick={() => {
                      if (!dishEditForm.name.trim() || !dishEditForm.categoryId) {
                        setError("Vui lòng nhập tên món và chọn danh mục.");
                        return;
                      }
                      const payload = {
                        name: dishEditForm.name.trim(),
                        price: Number(dishEditForm.price || "0"),
                        categoryId: Number(dishEditForm.categoryId),
                        description: dishEditForm.description.trim(),
                        unit: dishEditForm.unit.trim() || "dia",
                        image: dishEditForm.image || null,
                        isVegetarian: dishEditForm.isVegetarian,
                        isDailySpecial: dishEditForm.isDailySpecial,
                        available: dishEditForm.available,
                        isActive: dishEditForm.isActive,
                      };
                      void (async () => {
                        const imageFile = await pickDishImage();
                        await refreshAndShow(imageFile ? adminApi.updateDishWithImage(dishEditForm.dishId, payload, imageFile) : adminApi.updateDish(dishEditForm.dishId, payload));
                        setDishEditForm({ dishId: 0, name: "", price: "10000", categoryId: "", description: "", unit: "dia", image: "", isVegetarian: false, isDailySpecial: false, available: true, isActive: true });
                        navigate("/Admin/Dishes/Index");
                      })();
                    }}>Lưu thay đổi</button>
                  </div>
                </>
              )}
            </div>
          ) : null}

          {isDishIngredientsPage ? (
            dishIngredientEditor ? (
              <div className="panel">
                <div className="panel-head">
                  <div><h2>Thành phần món ăn</h2><p className="muted">{dishIngredientEditor.dishName}</p></div>
                  <button className="ghost" onClick={() => { setDishIngredientEditor(null); navigate("/Admin/Dishes/Index"); }}>Quay lại danh sách món ăn</button>
                </div>
                <div className="ingredient-modal-list">
                  {dishIngredientEditor.items.map((item, index) => (
                    <div key={item.ingredientId} className={`ingredient-line ${item.selected ? "selected" : ""}`}>
                      <label className="ingredient-toggle">
                        <input
                          type="checkbox"
                          checked={item.selected}
                          onChange={(e) => {
                            const next = [...dishIngredientEditor.items];
                            next[index] = { ...item, selected: e.target.checked, quantityPerDish: e.target.checked ? (item.quantityPerDish || 1) : 0 };
                            setDishIngredientEditor({ ...dishIngredientEditor, items: next });
                          }}
                        />
                        <span>
                          <strong>{item.name}</strong>
                          <small className="muted-caption">{item.unit} | Tồn {item.currentStock}</small>
                        </span>
                      </label>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={item.selected ? item.quantityPerDish : 0}
                        disabled={!item.selected}
                        onChange={(e) => {
                          const next = [...dishIngredientEditor.items];
                          next[index] = { ...item, quantityPerDish: Number(e.target.value) };
                          setDishIngredientEditor({ ...dishIngredientEditor, items: next });
                        }}
                      />
                    </div>
                  ))}
                </div>
                <div className="button-row">
                  <button className="ghost" onClick={() => { setDishIngredientEditor(null); navigate("/Admin/Dishes/Index"); }}>Hủy</button>
                  <button onClick={() => void saveDishIngredientsEditor().then(() => navigate("/Admin/Dishes/Index"))}>Lưu thành phần</button>
                </div>
              </div>
            ) : (
              <div className="empty-report history-empty-card">
                <i className="bi bi-basket3-fill" />
                <strong>Chưa có món ăn đang mở phần thành phần</strong>
                  <div>Hãy quay lại danh sách món ăn và chọn một món để mở phần nguyên liệu.</div>
              </div>
            )
          ) : null}

          {!isDishCreatePage && !isDishEditPage && !isDishIngredientsPage ? (
            <>
              <div className="panel-head"><h2>Danh sách món ăn</h2><span className="status-pill success">{dishes.dishes.totalItems} món</span></div>
              <table className="data-table">
                <thead><tr><th>Hình</th><th>Tên món</th><th>Danh mục</th><th>Giá</th><th>Tình trạng</th><th>Thao tác</th></tr></thead>
                <tbody>
                  {visibleDishes.length > 0 ? visibleDishes.map((dish) => (
                    <tr key={dish.dishId}>
                      <td><img className="thumb" src={dish.image || "/images/placeholder-dish.svg"} alt={dish.name} /></td>
                      <td><strong>{dish.name}</strong><div className="muted">{dish.description || "Chưa có mô tả"}</div></td>
                      <td><span className="status-pill info">{dish.categoryName}</span></td>
                      <td>{dish.price.toLocaleString("vi-VN")} đ</td>
                      <td>{dish.available ? <span className="status-pill success">Đang bán</span> : <span className="status-pill warning">Tạm ngưng</span>}</td>
                      <td>
                        <div className="button-row wrap">
                          <button className="ghost" onClick={() => openDishEditPage(dish)}>Sửa</button>
                          <button className="ghost" onClick={() => void refreshAndShow(adminApi.setDishAvailability(dish.dishId, !dish.available))}>{dish.available ? "Tạm ngưng" : "Mở bán"}</button>
                          <button className="ghost" onClick={() => void openDishIngredients(dish.dishId, dish.name)}>Nguyên liệu</button>
                          <button className="danger" onClick={() => void refreshAndShow(adminApi.deactivateDish(dish.dishId))}>Vô hiệu</button>
                        </div>
                      </td>
                    </tr>
                  )) : <tr><td colSpan={6} className="text-right">Chưa có món ăn phù hợp với bộ lọc hiện tại.</td></tr>}
                </tbody>
              </table>
              {renderPagination(dishes.dishes, dishPage, setDishPage, "dish")}
            </>
          ) : null}
        </section>
      ) : null}

      {section === "ingredients" ? (
        <section className="panel">
          <div className="toolbar-card">
            <div><strong>Quản lý nguyên liệu</strong><div className="muted">Quản lý nguyên liệu và tồn kho.</div></div>
            <div className="button-row wrap">
              {isIngredientEditPage ? <button className="ghost" onClick={() => navigate("/Admin/Ingredients/Index")}>Quay lại danh sách</button> : null}
              <button className={isIngredientCreatePage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Ingredients/Create")}>Thêm nguyên liệu</button>
              <button className={isIngredientEditPage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Ingredients/Edit")}>Sửa nguyên liệu</button>
            </div>
          </div>

          {!isIngredientEditPage ? (
            <>
              <div className="entry-form-card">
                <div className="entry-form-header"><div><strong>Thêm nguyên liệu</strong><div className="muted">Nhập tên, đơn vị, tồn kho và mức cảnh báo.</div></div></div>
                <div className="entry-form-grid">
                  <label>Tên nguyên liệu<input value={ingredientForm.name} onChange={(e) => setIngredientForm({ ...ingredientForm, name: e.target.value })} /></label>
                  <label>Đơn vị<input value={ingredientForm.unit} onChange={(e) => setIngredientForm({ ...ingredientForm, unit: e.target.value })} /></label>
                  <label>Tồn kho<input type="number" value={ingredientForm.currentStock} onChange={(e) => setIngredientForm({ ...ingredientForm, currentStock: e.target.value })} /></label>
                  <label>Mức cảnh báo<input type="number" value={ingredientForm.reorderLevel} onChange={(e) => setIngredientForm({ ...ingredientForm, reorderLevel: e.target.value })} /></label>
                </div>
                <div className="entry-form-actions">
                  <span className="muted">Giữ đúng cấu trúc biểu mẫu thêm nguyên liệu.</span>
                  <button onClick={() => {
                    if (!ingredientForm.name.trim()) {
                      setError("Tên nguyên liệu không được để trống.");
                      return;
                    }
                    void refreshAndShow(adminApi.createIngredient({
                      name: ingredientForm.name.trim(),
                      unit: ingredientForm.unit.trim() || "kg",
                      currentStock: Number(ingredientForm.currentStock || "0"),
                      reorderLevel: Number(ingredientForm.reorderLevel || "0"),
                      isActive: true,
                    })).then(() => {
                      setIngredientForm(emptyIngredientForm);
                      if (isIngredientCreatePage) navigate("/Admin/Ingredients/Index");
                    });
                  }}>Thêm nguyên liệu</button>
                </div>
              </div>

              <div className="inline-filter-card admin-filter-card">
                <div><strong>Bộ lọc nguyên liệu</strong><div className="muted">Tìm theo tên hoặc đơn vị, có thể chỉ hiện nguyên liệu còn hoạt động.</div></div>
                <div className="admin-filter-form">
                  <label className="admin-filter-field admin-filter-field-wide"><span>Tìm kiếm</span><input value={ingredientSearch} onChange={(e) => { setIngredientPage(1); setIngredientSearch(e.target.value); }} placeholder="Tên hoặc đơn vị..." /></label>
                  <label className="admin-filter-check"><input type="checkbox" checked={ingredientOnlyActive} onChange={(e) => { setIngredientPage(1); setIngredientOnlyActive(e.target.checked); }} /><span>Chỉ còn hoạt động</span></label>
                </div>
                <div className="admin-filter-actions"><button className="ghost" onClick={() => { setIngredientPage(1); setIngredientSearch(""); setIngredientOnlyActive(false); }}>Xóa bộ lọc</button></div>
              </div>
            </>
          ) : null}

          {(ingredientEditForm.ingredientId > 0 || isIngredientEditPage) ? (
            <div className="entry-form-card edit-form-card">
              <div className="entry-form-header">
                <div><strong>Chỉnh sửa nguyên liệu</strong><div className="muted">Cập nhật nguyên liệu đang chọn.</div></div>
                <button className="ghost" onClick={() => { setIngredientEditForm({ ingredientId: 0, name: "", unit: "kg", currentStock: "0", reorderLevel: "0", isActive: true }); navigate("/Admin/Ingredients/Index"); }}>Đóng</button>
              </div>
              {ingredientEditForm.ingredientId === 0 ? (
                <div className="empty-report history-empty-card">
                  <i className="bi bi-basket3-fill" />
                  <strong>Chưa có nguyên liệu đang chỉnh sửa</strong>
                  <div>Hãy chọn một nguyên liệu từ danh sách để mở biểu mẫu chỉnh sửa.</div>
                </div>
              ) : (
                <>
                  <div className="entry-form-grid">
                    <label>Tên nguyên liệu<input value={ingredientEditForm.name} onChange={(e) => setIngredientEditForm({ ...ingredientEditForm, name: e.target.value })} /></label>
                    <label>Đơn vị<input value={ingredientEditForm.unit} onChange={(e) => setIngredientEditForm({ ...ingredientEditForm, unit: e.target.value })} /></label>
                    <label>Tồn kho<input type="number" value={ingredientEditForm.currentStock} onChange={(e) => setIngredientEditForm({ ...ingredientEditForm, currentStock: e.target.value })} /></label>
                    <label>Mức cảnh báo<input type="number" value={ingredientEditForm.reorderLevel} onChange={(e) => setIngredientEditForm({ ...ingredientEditForm, reorderLevel: e.target.value })} /></label>
                  </div>
                  <div className="filter-chip-row">
                    <button type="button" className={`ghost ${ingredientEditForm.isActive ? "active-toggle" : ""}`} onClick={() => setIngredientEditForm({ ...ingredientEditForm, isActive: !ingredientEditForm.isActive })}>
                      {ingredientEditForm.isActive ? "Hoạt động" : "Ngừng hoạt động"}
                    </button>
                  </div>
                  <div className="entry-form-actions">
                    <span className="muted">Biểu mẫu chỉnh sửa được tách riêng để giữ đúng luồng quản trị.</span>
                    <div className="button-row wrap">
                      <button className="danger" onClick={() => void removeIngredient({
                        ingredientId: ingredientEditForm.ingredientId,
                        name: ingredientEditForm.name,
                        unit: ingredientEditForm.unit,
                        currentStock: Number(ingredientEditForm.currentStock || "0"),
                        reorderLevel: Number(ingredientEditForm.reorderLevel || "0"),
                        isActive: ingredientEditForm.isActive,
                      })}>Xóa</button>
                      <button onClick={() => {
                      if (!ingredientEditForm.name.trim()) {
                        setError("Tên nguyên liệu không được để trống.");
                        return;
                      }
                      void refreshAndShow(adminApi.updateIngredient(ingredientEditForm.ingredientId, {
                        name: ingredientEditForm.name.trim(),
                        unit: ingredientEditForm.unit.trim() || "kg",
                        currentStock: Number(ingredientEditForm.currentStock || "0"),
                        reorderLevel: Number(ingredientEditForm.reorderLevel || "0"),
                        isActive: ingredientEditForm.isActive,
                      })).then(() => {
                        setIngredientEditForm({ ingredientId: 0, name: "", unit: "kg", currentStock: "0", reorderLevel: "0", isActive: true });
                        navigate("/Admin/Ingredients/Index");
                      });
                      }}>Lưu thay đổi</button>
                    </div>
                  </div>
                </>
              )}
            </div>
          ) : null}

          {!isIngredientEditPage ? (
            <>
              <div className="panel-head"><h2>Danh sách nguyên liệu</h2><span className="status-pill success">{ingredients.ingredients.totalItems} nguyên liệu</span></div>
              <table className="data-table">
                <thead><tr><th>Tên nguyên liệu</th><th>Đơn vị</th><th>Tồn kho</th><th>Mức cảnh báo</th><th>Trạng thái</th><th>Thao tác</th></tr></thead>
                <tbody>
                  {visibleIngredients.length > 0 ? visibleIngredients.map((ingredient) => (
                    <tr key={ingredient.ingredientId}>
                      <td><strong>{ingredient.name}</strong></td>
                      <td>{ingredient.unit}</td>
                      <td>{ingredient.currentStock}</td>
                      <td>{ingredient.reorderLevel}</td>
                      <td>{ingredient.isActive ? <span className="status-pill success">Hoạt động</span> : <span className="status-pill danger">Ngừng hoạt động</span>}</td>
                      <td>
                        <div className="button-row wrap">
                          <button className="ghost" onClick={() => openIngredientEditPage(ingredient)}>Sửa</button>
                          <button className="danger" onClick={() => void removeIngredient(ingredient)}>Xóa</button>
                          <button className="danger" onClick={() => void refreshAndShow(adminApi.deactivateIngredient(ingredient.ingredientId))}>Vô hiệu</button>
                        </div>
                      </td>
                    </tr>
                  )) : <tr><td colSpan={6} className="text-right">Chưa có nguyên liệu phù hợp với bộ lọc hiện tại.</td></tr>}
                </tbody>
              </table>
              {renderPagination(ingredients.ingredients, ingredientPage, setIngredientPage, "ingredient")}
            </>
          ) : null}
        </section>
      ) : null}

      {section === "tables" ? (
        <section className="panel">
          <div className="toolbar-card">
            <div><strong>Quản lý bàn & mã QR</strong><div className="muted">Quản lý bàn ăn và mã QR.</div></div>
            <div className="button-row wrap">
              {(isTableEditPage || isTableQrPage) ? <button className="ghost" onClick={() => navigate("/Admin/TablesQR/Index")}>Quay lại danh sách bàn</button> : null}
              <button className={isTableEditPage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/TablesQR/Edit")}>Sửa bàn</button>
              <button className={isTableQrPage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/TablesQR/QR")}>Mã QR</button>
            </div>
          </div>

          {!isTableEditPage && !isTableQrPage ? (
            <>
              <div className="entry-form-card">
                <div className="entry-form-header"><div><strong>Thêm bàn mới</strong><div className="muted">Chọn chi nhánh, số ghế và trạng thái.</div></div></div>
                <div className="entry-form-grid">
                  <label>Chi nhánh<select value={tableForm.branchId} onChange={(e) => setTableForm({ ...tableForm, branchId: e.target.value })}>{tablesData.branches.map((branch) => <option key={branch.branchId} value={branch.branchId}>{branch.name}</option>)}</select></label>
                  <label>Số ghế<input type="number" value={tableForm.numberOfSeats} onChange={(e) => setTableForm({ ...tableForm, numberOfSeats: e.target.value })} /></label>
                  <label>Trạng thái<select value={tableForm.statusId} onChange={(e) => setTableForm({ ...tableForm, statusId: e.target.value })}>{tablesData.tableStatuses.map((status) => <option key={status.statusId} value={status.statusId}>{status.statusName}</option>)}</select></label>
                </div>
                <div className="entry-form-actions">
                  <span className="muted">Thêm bàn mới cho chi nhánh đang quản lý.</span>
                  <button onClick={() => {
                    if (!tableForm.branchId || !tableForm.statusId) {
                      setError("Vui lòng chọn chi nhánh và trạng thái bàn.");
                      return;
                    }
                    void refreshAndShow(adminApi.createTable({
                      branchId: Number(tableForm.branchId),
                      numberOfSeats: Number(tableForm.numberOfSeats || "4"),
                      statusId: Number(tableForm.statusId),
                      isActive: true,
                    })).then(() => setTableForm({
                      branchId: String(tablesData.branches[0]?.branchId ?? ""),
                      numberOfSeats: "4",
                      statusId: String(tablesData.tableStatuses[0]?.statusId ?? ""),
                    }));
                  }}>Thêm bàn</button>
                </div>
              </div>

              <div className="inline-filter-card admin-filter-card">
                <div><strong>Bộ lọc bàn ăn</strong><div className="muted">Tìm theo chi nhánh, bàn, số ghế hoặc trạng thái.</div></div>
                <div className="admin-filter-form">
                  <label className="admin-filter-field admin-filter-field-wide"><span>Tìm kiếm</span><input value={tableSearch} onChange={(e) => { setTablePage(1); setTableSearch(e.target.value); }} placeholder="Tên chi nhánh, số bàn, trạng thái..." /></label>
                  <label className="admin-filter-field"><span>Chi nhánh</span><select value={tableBranchFilter} onChange={(e) => { setTablePage(1); setTableBranchFilter(e.target.value); }}><option value="ALL">Tất cả chi nhánh</option>{tablesData.branches.map((branch) => <option key={branch.branchId} value={branch.branchId}>{branch.name}</option>)}</select></label>
                </div>
                <div className="admin-filter-actions"><button className="ghost" onClick={() => { setTablePage(1); setTableSearch(""); setTableBranchFilter("ALL"); }}>Xóa bộ lọc</button></div>
              </div>
            </>
          ) : null}

          {(tableEditForm.tableId > 0 || isTableEditPage) ? (
            <div className="entry-form-card edit-form-card">
              <div className="entry-form-header">
                <div><strong>Chỉnh sửa bàn</strong><div className="muted">Cập nhật bàn đang chọn.</div></div>
                <button className="ghost" onClick={() => { setTableEditForm({ tableId: 0, branchId: "", numberOfSeats: "4", statusId: "", qrCode: "", isActive: true }); navigate("/Admin/TablesQR/Index"); }}>Đóng</button>
              </div>
              {tableEditForm.tableId === 0 ? (
                <div className="empty-report history-empty-card">
                  <i className="bi bi-grid-3x3-gap-fill" />
                  <strong>Chưa có bàn đang chỉnh sửa</strong>
                  <div>Hãy chọn một bàn từ danh sách để mở biểu mẫu chỉnh sửa.</div>
                </div>
              ) : (
                <>
                  <div className="entry-form-grid">
                    <label>Chi nhánh<select value={tableEditForm.branchId} onChange={(e) => setTableEditForm({ ...tableEditForm, branchId: e.target.value })}>{tablesData.branches.map((branch) => <option key={branch.branchId} value={branch.branchId}>{branch.name}</option>)}</select></label>
                    <label>Số ghế<input type="number" value={tableEditForm.numberOfSeats} onChange={(e) => setTableEditForm({ ...tableEditForm, numberOfSeats: e.target.value })} /></label>
                    <label>Trạng thái<select value={tableEditForm.statusId} onChange={(e) => setTableEditForm({ ...tableEditForm, statusId: e.target.value })}>{tablesData.tableStatuses.map((status) => <option key={status.statusId} value={status.statusId}>{status.statusName}</option>)}</select></label>
                    <label className="full-span">Mã QR<input value={tableEditForm.qrCode} readOnly /></label>
                  </div>
                  <div className="filter-chip-row">
                    <button type="button" className={`ghost ${tableEditForm.isActive ? "active-toggle" : ""}`} onClick={() => setTableEditForm({ ...tableEditForm, isActive: !tableEditForm.isActive })}>
                      {tableEditForm.isActive ? "Hoạt động" : "Ngừng hoạt động"}
                    </button>
                  </div>
                  <div className="entry-form-actions">
                    <span className="muted">Giữ đúng luồng chỉnh sửa bàn và mã QR.</span>
                    <button onClick={() => {
                      if (!tableEditForm.branchId || !tableEditForm.statusId) {
                        setError("Vui lòng chọn chi nhánh và trạng thái bàn.");
                        return;
                      }
                      void refreshAndShow(adminApi.updateTable(tableEditForm.tableId, {
                        branchId: Number(tableEditForm.branchId),
                        numberOfSeats: Number(tableEditForm.numberOfSeats || "4"),
                        statusId: Number(tableEditForm.statusId),
                        isActive: tableEditForm.isActive,
                      })).then(() => {
                        setTableEditForm({ tableId: 0, branchId: "", numberOfSeats: "4", statusId: "", qrCode: "", isActive: true });
                        navigate("/Admin/TablesQR/Index");
                      });
                    }}>Lưu thay đổi</button>
                  </div>
                </>
              )}
            </div>
          ) : null}

          {isTableQrPage ? (
            <>
              <div className="panel-head"><h2>Danh sách mã QR bàn</h2><span className="status-pill success">{tablesData.tables.totalItems} bàn</span></div>
              <div className="panel-grid">
                {visibleTables.map((table) => (
                  <article key={`qr-${table.tableId}`} className="panel">
                    <div className="panel-head">
                      <h2>Bàn {table.tableId}</h2>
                      <span>{table.branchName}</span>
                    </div>
                    <div className="list-card">
                      <img className="qr-preview" src={buildQrImageUrl(table.qrCode)} alt={`QR bàn ${table.tableId}`} />
                      <p>{buildQrTargetUrl(table.qrCode)}</p>
                    </div>
                  </article>
                ))}
              </div>
              {renderPagination(tablesData.tables, tablePage, setTablePage, "table-qr")}
            </>
          ) : null}

          {!isTableEditPage && !isTableQrPage ? (
            <>
              <div className="panel-head"><h2>Danh sách bàn ăn</h2><span className="status-pill success">{tablesData.tables.totalItems} bàn</span></div>
              <table className="data-table">
                <thead><tr><th>Bàn</th><th>Chi nhánh</th><th>Số ghế</th><th>Trạng thái</th><th>QR</th><th>Thao tác</th></tr></thead>
                <tbody>
                  {visibleTables.length > 0 ? visibleTables.map((table) => (
                    <tr key={table.tableId}>
                      <td><strong>Bàn {table.tableId}</strong></td>
                      <td>{table.branchName}</td>
                      <td>{table.numberOfSeats}</td>
                      <td><span className="status-pill info">{table.statusName}</span></td>
                      <td>{table.qrCode || "-"}</td>
                      <td>
                        <div className="button-row wrap">
                          <button className="ghost" onClick={() => openTableEditPage(table)}>Sửa</button>
                          <button className="ghost" onClick={() => navigate("/Admin/TablesQR/QR")}>QR</button>
                          <button className="danger" onClick={() => void refreshAndShow(adminApi.deactivateTable(table.tableId))}>Vô hiệu</button>
                        </div>
                      </td>
                    </tr>
                  )) : <tr><td colSpan={6} className="text-right">Chưa có bàn phù hợp với bộ lọc hiện tại.</td></tr>}
                </tbody>
              </table>
              {renderPagination(tablesData.tables, tablePage, setTablePage, "table")}
            </>
          ) : null}
        </section>
      ) : null}

      {section === "reports" ? (
        <section className="panel-grid">
          {isRevenuePage ? (
            <article className="panel">
              <div className="toolbar-card">
                <div><strong>Báo cáo doanh thu</strong><div className="muted">Tổng quan doanh thu theo ngày và chi nhánh.</div></div>
                <div className="button-row wrap">
                  <button className={isRevenuePage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Reports/Revenue")}>Doanh thu</button>
                  <button className={isTopDishesPage ? "active-toggle" : "ghost"} onClick={() => navigate("/Admin/Reports/TopDishes")}>Top món ăn</button>
                </div>
              </div>
              <div className="history-filter-shell">
                <div className="history-filter-tabs">
                  {reportBranchOptions.map((option) => (
                    <button key={option.key} className={`history-filter-tab ${reportBranchFilter === option.key ? "active" : ""}`} onClick={() => setReportBranchFilter(option.key)}>
                      {option.label} <span>{option.count}</span>
                    </button>
                  ))}
                </div>
              </div>
              <div className="panel-head"><h2>Báo cáo doanh thu</h2><span>{filteredRevenueTotal.toLocaleString("vi-VN")} đ</span></div>
              {filteredRevenueRows.length === 0 ? (
                <div className="empty-report"><i className="bi bi-graph-up-arrow" /><p>Chưa có dữ liệu doanh thu.</p></div>
              ) : (
                <table className="data-table">
                  <thead><tr><th>Ngày</th><th>Chi nhánh</th><th>Số đơn</th><th>Doanh thu</th></tr></thead>
                  <tbody>
                    {filteredRevenueRows.map((row, index) => (
                      <tr key={`${row.branchId}-${row.date}-${index}`}>
                        <td>{row.date}</td>
                        <td>{row.branchName}</td>
                        <td>{row.totalOrders}</td>
                        <td>{row.totalRevenue.toLocaleString("vi-VN")} đ</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </article>
          ) : null}

          {isTopDishesPage ? (
            <article className="panel">
              <div className="toolbar-card">
                <div><strong>Món ăn được gọi nhiều nhất</strong><div className="muted">Top món theo số lượng bán ra.</div></div>
                <div className="button-row wrap"><button className="ghost" onClick={() => navigate("/Admin/Reports/Revenue")}>Quay lại báo cáo doanh thu</button></div>
              </div>
              <table className="data-table">
                <thead><tr><th>#</th><th>Món ăn</th><th>Danh mục</th><th>Số lượng</th><th>Doanh thu</th></tr></thead>
                <tbody>
                  {reports.topDishes.items.map((item, index) => (
                    <tr key={item.dishId}>
                      <td>{index + 1}</td>
                      <td><strong>{item.dishName}</strong></td>
                      <td>{item.categoryName}</td>
                      <td>{item.totalQuantity}</td>
                      <td>{item.totalRevenue.toLocaleString("vi-VN")} đ</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </article>
          ) : null}
        </section>
      ) : null}

      {section === "settings" ? (
        <section className="panel">
          <div className="panel-head">
            <div><h2>Cài đặt tài khoản</h2><p className="muted">Cập nhật thông tin cá nhân và mật khẩu.</p></div>
            <span className="status-pill info"><i className="bi bi-person-badge-fill" /> {dashboard.settings.username}</span>
          </div>

          <section className="entry-form-card settings-form-card">
            <div className="entry-form-header">
              <div><strong>Thông tin liên hệ</strong><div className="muted">{dashboard.settings.branchName} | {dashboard.settings.roleName}</div></div>
            </div>
            <div className="entry-form-grid">
              <label>Tên đăng nhập<input value={dashboard.settings.username} readOnly /></label>
              <label>Họ tên<input value={settingsDraft.name} onChange={(e) => setSettingsDraft({ ...settingsDraft, name: e.target.value })} /></label>
              <label>Số điện thoại<input value={settingsDraft.phone} onChange={(e) => setSettingsDraft({ ...settingsDraft, phone: e.target.value })} /></label>
              <label className="full-span">Email<input value={settingsDraft.email} onChange={(e) => setSettingsDraft({ ...settingsDraft, email: e.target.value })} /></label>
            </div>
            <div className="entry-form-actions">
              <span className="muted">Cập nhật đúng thông tin tài khoản quản trị.</span>
              <div className="button-row wrap">
                <button className="ghost" onClick={() => setSettingsDraft({ name: dashboard.settings.name, phone: dashboard.settings.phone ?? "", email: dashboard.settings.email ?? "" })}>Đặt lại</button>
                <button onClick={() => void saveSettings()}>Lưu thay đổi</button>
              </div>
            </div>
          </section>

          <section className="entry-form-card settings-security-card">
            <div className="entry-form-header">
              <div><strong>Đổi mật khẩu</strong><div className="muted">Nếu không muốn đổi mật khẩu, hãy để trống các ô bên dưới.</div></div>
              <span className="status-pill warning"><i className="bi bi-key-fill" /> Mật khẩu quản trị</span>
            </div>
            <div className="entry-form-grid">
              <label>Mật khẩu hiện tại<input type="password" value={passwordEditor.currentPassword} onChange={(e) => setPasswordEditor({ ...passwordEditor, currentPassword: e.target.value })} /></label>
              <label>Mật khẩu mới<input type="password" value={passwordEditor.newPassword} onChange={(e) => setPasswordEditor({ ...passwordEditor, newPassword: e.target.value })} /></label>
              <label className="full-span">Nhập lại mật khẩu mới<input type="password" value={passwordEditor.confirmPassword} onChange={(e) => setPasswordEditor({ ...passwordEditor, confirmPassword: e.target.value })} /></label>
            </div>
            <div className="entry-form-actions">
              <div className="muted">Nếu không muốn đổi mật khẩu, hãy để trống các ô bên trên.</div>
              <div className="button-row wrap">
                <button className="ghost" onClick={() => setPasswordEditor({ currentPassword: "", newPassword: "", confirmPassword: "" })}>Hủy nhập</button>
                <button className="ghost" onClick={() => void onLogout()}>Đăng xuất</button>
                <button onClick={() => void savePasswordChange()}>Lưu mật khẩu</button>
              </div>
            </div>
          </section>
        </section>
      ) : null}
    </AdminLayout>
  );
}
