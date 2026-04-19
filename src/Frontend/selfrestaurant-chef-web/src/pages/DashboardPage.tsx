import { useEffect, useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { chefApi } from "../lib/api";
import type {
  ChefCategoryDto,
  ChefDashboardDto,
  ChefDishIngredientsDto,
  ChefMenuDishDto,
  ChefOrderDto,
  ChefUpsertDishPayload,
} from "../lib/types";

type Props = {
  onLogout: () => Promise<void>;
};

type DishEditorState = {
  mode: "create" | "edit";
  dishId?: number;
  originalImage?: string | null;
  draft: ChefUpsertDishPayload;
};

type IngredientEditorState = ChefDishIngredientsDto & {
  customerNote?: string | null;
};

const DISH_UNIT_OPTIONS = ["Phần", "Tô", "Ly", "Đĩa", "Suất", "Kg", "Lít"] as const;

const CHEF_TEXT_MAP: Record<string, string> = {
  "Ban can dang nhap bang tai khoan bep.": "Bạn cần đăng nhập bằng tài khoản bếp.",
  "Mi Xao Bo": "Mì Xào Bò",
  "Bun Cha Ha Noi": "Bún Chả Hà Nội",
  "Com Suon Bi Cha": "Cơm Sườn Bì Chả",
  "Bun Bo Hue": "Bún Bò Huế",
  "Hu Tieu Nam Vang": "Hủ Tiếu Nam Vang",
  "Mi xao bo dam da huong vi": "Mì xào bò đậm đà hương vị",
  "Bun cha dac san Ha Noi voi cha nuong than hong": "Bún chả đặc sản Hà Nội với chả nướng than hồng",
  "Com suon bi cha truyen thong Sai Gon": "Cơm sườn bì chả truyền thống Sài Gòn",
  "Bun bo Hue cay nong dam da": "Bún bò Huế cay nồng đậm đà",
  "Hu tieu Nam Vang dac biet": "Hủ tiếu Nam Vang đặc biệt",
  "Dang ban": "Đang bán",
  "Tam ngung ban": "Tạm ngưng bán",
  "Tam dung ban": "Tạm dừng bán",
  "Mon noi bat": "Món nổi bật",
  "Mon chinh": "Món chính",
  "Mon phu": "Món phụ",
  "Trang mieng": "Tráng miệng",
  "Do uong": "Đồ uống",
  "Mon chay": "Món chay",
  "Mon dac biet": "Món đặc biệt",
  "Hien thi tren thuc don": "Hiển thị trên thực đơn",
  "Da cap nhat thong tin mon an.": "Đã cập nhật thông tin món ăn.",
  "Da them mon moi.": "Đã thêm món mới.",
  "Da luu nguyen lieu mon.": "Đã lưu nguyên liệu món.",
  "Cho che bien": "Chờ chế biến",
  "Dang che bien": "Đang chế biến",
  "San sang": "Sẵn sàng",
  "Nguyen lieu": "Nguyên liệu",
  "Phan": "Phần",
  "To": "Tô",
  "Dia": "Đĩa",
  "Suat": "Suất",
};

function normalizeChefText(value?: string | null): string {
  if (!value) return "";

  let normalized = value.replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
    String.fromCharCode(Number.parseInt(hex, 16)),
  );

  for (const [source, target] of Object.entries(CHEF_TEXT_MAP)) {
    normalized = normalized.split(source).join(target);
  }

  return normalized.trim();
}

function normalizeChefDashboard(data: ChefDashboardDto): ChefDashboardDto {
  return {
    ...data,
    staff: {
      ...data.staff,
      name: normalizeChefText(data.staff.name),
      roleName: normalizeChefText(data.staff.roleName),
      branchName: normalizeChefText(data.staff.branchName),
    },
    pendingOrders: data.pendingOrders.map(normalizeChefOrder),
    preparingOrders: data.preparingOrders.map(normalizeChefOrder),
    readyOrders: data.readyOrders.map(normalizeChefOrder),
    history: data.history.map((item) => ({
      ...item,
      tableName: normalizeChefText(item.tableName),
      statusName: normalizeChefText(item.statusName),
      dishesSummary: normalizeChefText(item.dishesSummary),
    })),
    menu: {
      ...data.menu,
      branchName: normalizeChefText(data.menu.branchName),
      dishes: data.menu.dishes.map((dish) => ({
        ...dish,
        name: normalizeChefText(dish.name),
        unit: normalizeChefText(dish.unit) || "Phần",
        categoryName: normalizeChefText(dish.categoryName),
        description: normalizeChefText(dish.description),
      })),
    },
    ingredients: data.ingredients.map((item) => ({
      ...item,
      name: normalizeChefText(item.name),
      unit: normalizeChefText(item.unit),
    })),
  };
}

function normalizeChefOrder(order: ChefOrderDto): ChefOrderDto {
  return {
    ...order,
    tableName: normalizeChefText(order.tableName),
    statusName: normalizeChefText(order.statusName),
    items: order.items.map((item) => ({
      ...item,
      dishName: normalizeChefText(item.dishName),
      note: normalizeChefText(item.note),
    })),
  };
}

function normalizeChefCategories(items: ChefCategoryDto[]): ChefCategoryDto[] {
  return items.map((item) => ({
    ...item,
    name: normalizeChefText(item.name),
    description: normalizeChefText(item.description),
  }));
}

function normalizeIngredientEditorPayload(payload: ChefDishIngredientsDto): ChefDishIngredientsDto {
  return {
    ...payload,
    dishName: normalizeChefText(payload.dishName),
    items: payload.items.map((item) => ({
      ...item,
      name: normalizeChefText(item.name),
      unit: normalizeChefText(item.unit),
    })),
  };
}

export function DashboardPage({ onLogout }: Props) {
  const location = useLocation();
  const [activeTab, setActiveTab] = useState<"orders" | "menu">("orders");
  const [dishSearch, setDishSearch] = useState("");
  const [dishStatusFilter, setDishStatusFilter] = useState<"ALL" | "AVAILABLE" | "PAUSED">("ALL");
  const [dishSpecialFilter, setDishSpecialFilter] = useState<"ALL" | "SPECIAL" | "NORMAL">("ALL");
  const [data, setData] = useState<ChefDashboardDto | null>(null);
  const [categories, setCategories] = useState<ChefCategoryDto[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [accountDraft, setAccountDraft] = useState({ name: "", phone: "", email: "" });
  const [passwordDraft, setPasswordDraft] = useState({ currentPassword: "", newPassword: "", confirmPassword: "" });
  const [ingredientEditor, setIngredientEditor] = useState<IngredientEditorState | null>(null);
  const [ingredientStockOpen, setIngredientStockOpen] = useState(false);
  const [ingredientStockSearch, setIngredientStockSearch] = useState("");
  const [onlyLowStock, setOnlyLowStock] = useState(false);
  const [cancelEditor, setCancelEditor] = useState<{ orderId: number; orderCode: string; reason: string } | null>(null);
  const [dishEditor, setDishEditor] = useState<DishEditorState | null>(null);

  const filteredMenuDishes = useMemo(() => {
    if (!data) return [] as ChefMenuDishDto[];
    const query = dishSearch.trim().toLowerCase();
    return data.menu.dishes.filter((dish) => {
      const matchesSearch = query.length === 0 || dish.name.toLowerCase().includes(query);
      const matchesStatus =
        dishStatusFilter === "ALL" ||
        (dishStatusFilter === "AVAILABLE" ? dish.available : !dish.available);
      const matchesSpecial =
        dishSpecialFilter === "ALL" ||
        (dishSpecialFilter === "SPECIAL" ? dish.isDailySpecial : !dish.isDailySpecial);

      return matchesSearch && matchesStatus && matchesSpecial;
    });
  }, [data, dishSearch, dishSpecialFilter, dishStatusFilter]);

  const pageMode = location.pathname.toLowerCase().includes("/staff/chef/history") ? "history" : "index";

  function createEmptyDishDraft(categoryId?: number): ChefUpsertDishPayload {
    return {
      name: "",
      price: "",
      categoryId: categoryId ?? "",
      description: "",
      unit: "Phần",
      image: "",
      imageFile: null,
      isVegetarian: false,
      isDailySpecial: false,
      available: true,
      isActive: true,
    };
  }

  async function load(options?: { silent?: boolean }) {
    const silent = options?.silent ?? false;
    if (!silent) {
      setLoading(true);
    }
    setError(null);
    try {
      const [dashboard, categoryItems] = await Promise.all([
        chefApi.getDashboard(),
        chefApi.getCategories(),
      ]);
      setData(normalizeChefDashboard(dashboard));
      setCategories(normalizeChefCategories(categoryItems).filter((item) => item.isActive));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể tải dữ liệu bếp.");
    } finally {
      if (!silent) {
        setLoading(false);
      }
    }
  }

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => {
      void load({ silent: true });
    }, 4000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    setActiveTab(location.hash.toLowerCase() === "#menu" ? "menu" : "orders");
  }, [location.hash]);

  useEffect(() => {
    if (!data) return;
    setAccountDraft({
      name: data.staff.name,
      phone: data.staff.phone ?? "",
      email: data.staff.email ?? "",
    });
  }, [data]);

  useEffect(() => {
    if (!message) return;
    const timer = window.setTimeout(() => setMessage(null), 5000);
    return () => window.clearTimeout(timer);
  }, [message]);

  function formatShortDateTime(value?: string | null) {
    if (!value) return "Chưa cập nhật";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleString("vi-VN", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function getHistoryStatusClass(statusCode?: string | null) {
    const normalized = (statusCode ?? "").toUpperCase();
    if (normalized === "COMPLETED") return "chef-history-status chef-history-status-success";
    if (normalized === "READY" || normalized === "SERVING") return "chef-history-status chef-history-status-primary";
    if (normalized === "PREPARING") return "chef-history-status chef-history-status-warning";
    if (normalized === "CANCELLED") return "chef-history-status chef-history-status-danger";
    return "chef-history-status chef-history-status-muted";
  }

  async function act(fn: () => Promise<{ message?: string }>) {
    setMessage(null);
    setError(null);
    try {
      const result = await fn();
      setMessage(result.message ?? "Đã cập nhật.");
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể cập nhật.");
    }
  }

  async function openIngredients(dishId: number, customerNote?: string | null) {
    setError(null);
    try {
      setIngredientEditor({
        ...normalizeIngredientEditorPayload(await chefApi.getDishIngredients(dishId)),
        customerNote: normalizeChefText(customerNote),
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể tải nguyên liệu.");
    }
  }

  async function pickDishImage(): Promise<File | null> {
    return await new Promise<File | null>((resolve) => {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/*";
      input.onchange = () => resolve(input.files?.[0] ?? null);
      input.oncancel = () => resolve(null);
      input.click();
    });
  }

  async function saveIngredients() {
    if (!ingredientEditor) return;
    await act(async () => {
      const result = await chefApi.saveDishIngredients(ingredientEditor.dishId, ingredientEditor.items);
      setIngredientEditor((current) => ({
        ...normalizeIngredientEditorPayload(result),
        customerNote: current?.customerNote ?? null,
      }));
      return { message: "Đã lưu nguyên liệu món." };
    });
  }

  function openCreateDishModal() {
    setDishEditor({
      mode: "create",
      draft: createEmptyDishDraft(categories[0]?.categoryId),
    });
  }

  function openEditDishModal(dish: ChefMenuDishDto) {
    setDishEditor({
      mode: "edit",
      dishId: dish.dishId,
      originalImage: dish.image,
      draft: {
        name: dish.name,
        price: dish.price,
        categoryId: dish.categoryId,
        description: dish.description ?? "",
        unit: dish.unit ?? "Phần",
        image: dish.image ?? "",
        imageFile: null,
        isVegetarian: dish.isVegetarian,
        isDailySpecial: dish.isDailySpecial,
        available: dish.available,
        isActive: true,
      },
    });
  }

  async function saveDishEditor() {
    if (!dishEditor) return;
    const payload = dishEditor.draft;
    if (!payload.name.trim()) {
      setError("Vui lòng nhập tên món ăn.");
      return;
    }
    if (payload.price === "" || Number(payload.price) <= 0) {
      setError("Vui lòng nhập giá bán hợp lệ.");
      return;
    }
    if (payload.categoryId === "" || Number(payload.categoryId) <= 0) {
      setError("Vui lòng chọn danh mục món.");
      return;
    }

    await act(async () => {
      const normalizedPayload: ChefUpsertDishPayload = {
        ...payload,
        name: payload.name.trim(),
        price: Number(payload.price),
        categoryId: Number(payload.categoryId),
        unit: payload.unit?.trim() || DISH_UNIT_OPTIONS[0],
        description: payload.description?.trim() || "",
      };

      if (dishEditor.mode === "create") {
        const result = await chefApi.createDish(normalizedPayload);
        setDishEditor(null);
        return result;
      }

      const result = await chefApi.updateDish(dishEditor.dishId!, normalizedPayload);
      setDishEditor(null);
      return result;
    });
  }

  function resetDishEditorDraft() {
    setDishEditor((current) => {
      if (!current) return current;
      if (current.mode === "create") {
        return {
          ...current,
          draft: createEmptyDishDraft(categories[0]?.categoryId),
          originalImage: null,
        };
      }
      return current;
    });
  }

  async function saveAccount() {
    setMessage(null);
    setError(null);
    try {
      const updated = await chefApi.updateAccount(accountDraft);
      if (updated) {
        setData((current) => (current ? { ...current, staff: updated } : current));
      }
      setMessage("Cập nhật tài khoản thành công.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể cập nhật tài khoản.");
    }
  }

  async function changePassword() {
    setMessage(null);
    setError(null);
    if (
      passwordDraft.newPassword !== "" &&
      passwordDraft.confirmPassword !== "" &&
      passwordDraft.newPassword !== passwordDraft.confirmPassword
    ) {
      setError("Mật khẩu mới và xác nhận mật khẩu chưa khớp.");
      return;
    }
    try {
      const result = await chefApi.changePassword(passwordDraft);
      setMessage(result.message || "Đổi mật khẩu thành công.");
      setPasswordDraft({ currentPassword: "", newPassword: "", confirmPassword: "" });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể đổi mật khẩu.");
    }
  }

  async function submitCancel() {
    if (!cancelEditor?.reason.trim()) {
      setError("Vui lòng nhập lý do hủy đơn.");
      return;
    }
    await act(() => chefApi.cancelOrder(cancelEditor.orderId, cancelEditor.reason.trim()));
    setCancelEditor(null);
  }

  const ingredientStockRows = useMemo(() => {
    if (!data) return [];

    const query = ingredientStockSearch.trim().toLowerCase();
    return [...data.ingredients]
      .filter((item) => {
        const matchesQuery = query.length === 0 || item.name.toLowerCase().includes(query);
        const isLowStock = item.reorderLevel > 0 && item.currentStock <= item.reorderLevel;
        return matchesQuery && (!onlyLowStock || isLowStock);
      })
      .sort((a, b) => {
        const aLow = a.reorderLevel > 0 && a.currentStock <= a.reorderLevel ? 0 : 1;
        const bLow = b.reorderLevel > 0 && b.currentStock <= b.reorderLevel ? 0 : 1;
        return aLow - bLow || a.name.localeCompare(b.name, "vi");
      });
  }, [data, ingredientStockSearch, onlyLowStock]);
  const passwordMismatch =
    passwordDraft.newPassword !== "" &&
    passwordDraft.confirmPassword !== "" &&
    passwordDraft.newPassword !== passwordDraft.confirmPassword;

  if (loading) return <div className="screen-message">Đang tải bảng bếp...</div>;
  if (error && !data) return <div className="screen-message error-box">{error}</div>;
  if (!data) return null;

  if (pageMode === "history") {
    return (
      <main className="chef-shell chef-subpage chef-history-shell">
        <section className="hero-card chef-hero chef-history-hero">
          <header className="chef-header">
            <div>
              <p className="eyebrow">{data.staff.branchName}</p>
              <h1>Tài khoản & Lịch sử bếp</h1>
              <p className="muted">
                {data.staff.name} | {data.staff.roleName}
              </p>
            </div>
            <div className="header-actions">
              <Link className="ghost action-link" to="/Staff/Chef/Index">
                Quay về màn hình bếp
              </Link>
              <button className="ghost" onClick={() => void onLogout()}>
                Đăng xuất
              </button>
            </div>
          </header>
        </section>

        {message ? <div className="success-box">{message}</div> : null}
        {error ? <div className="error-box">{error}</div> : null}

        <section className="split-grid chef-history-grid">
          <div className="panel">
            <div className="panel-head">
              <h2>
                <i className="bi bi-person me-2" />
                Thông tin tài khoản
              </h2>
            </div>
            <div className="chef-panel-body">
              <form className="chef-account-form" onSubmit={(event) => event.preventDefault()}>
                <label>
                  Họ tên
                  <input
                    value={accountDraft.name}
                    onChange={(e) => setAccountDraft((current) => ({ ...current, name: e.target.value }))}
                  />
                </label>
                <label>
                  Tên đăng nhập
                  <input value={data.staff.username} disabled />
                </label>
                <label>
                  Email
                  <input
                    type="email"
                    value={accountDraft.email}
                    onChange={(e) => setAccountDraft((current) => ({ ...current, email: e.target.value }))}
                  />
                </label>
                <label>
                  Số điện thoại
                  <input
                    value={accountDraft.phone}
                    onChange={(e) => setAccountDraft((current) => ({ ...current, phone: e.target.value }))}
                  />
                </label>
                <div className="muted">
                  Chi nhánh: <strong>{data.staff.branchName}</strong> | Vai trò: <strong>{data.staff.roleName}</strong>
                </div>
                <button className="chef-primary-button" onClick={() => void saveAccount()}>
                  Lưu thay đổi
                </button>
              </form>

              <hr />

              <div className="stack">
                <h3 className="subsection-title">Đổi mật khẩu</h3>
                <label>
                  Mật khẩu hiện tại
                  <input
                    type="password"
                    value={passwordDraft.currentPassword}
                    onChange={(e) => setPasswordDraft((current) => ({ ...current, currentPassword: e.target.value }))}
                  />
                </label>
                <label>
                  Mật khẩu mới
                  <input
                    type="password"
                    value={passwordDraft.newPassword}
                    onChange={(e) => setPasswordDraft((current) => ({ ...current, newPassword: e.target.value }))}
                  />
                </label>
                <label>
                  Xác nhận mật khẩu mới
                  <input
                    type="password"
                    value={passwordDraft.confirmPassword}
                    onChange={(e) => setPasswordDraft((current) => ({ ...current, confirmPassword: e.target.value }))}
                  />
                </label>
                {passwordMismatch ? (
                  <div className="field-error">Mật khẩu xác nhận chưa khớp với mật khẩu mới.</div>
                ) : null}
                <button className="chef-outline-button" disabled={passwordMismatch} onClick={() => void changePassword()}>
                  Đổi mật khẩu
                </button>
              </div>
            </div>
          </div>

          <div className="panel">
            <div className="panel-head">
              <h2>
                <i className="bi bi-clock-history me-2" />
                Lịch sử đơn hàng bếp
              </h2>
            </div>
            <div className="table-scroll">
              <table className="staff-table">
                <thead>
                  <tr>
                    <th>Thời gian</th>
                    <th>Mã đơn</th>
                    <th>Bàn</th>
                    <th>Món</th>
                    <th>Trạng thái</th>
                  </tr>
                </thead>
                <tbody>
                  {data.history.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="muted table-empty">
                        Chưa có đơn hàng nào được ghi nhận.
                      </td>
                    </tr>
                  ) : (
                    data.history.slice(0, 100).map((item) => (
                      <tr key={item.orderId}>
                        <td>{formatShortDateTime(item.completedTime ?? item.orderTime)}</td>
                        <td>{item.orderCode || `ORD${item.orderId}`}</td>
                        <td>{item.tableName || "Không rõ bàn"}</td>
                        <td>{item.dishesSummary}</td>
                        <td>
                          <span className={getHistoryStatusClass(item.statusCode)}>{item.statusName}</span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
            {data.history.length > 0 ? (
              <p className="muted history-footnote">Hiển thị tối đa 100 đơn gần nhất tại chi nhánh của bạn.</p>
            ) : null}
          </div>
        </section>
      </main>
    );
  }

  return (
    <main className="chef-shell chef-index-shell">
      <section className="chef-mvc-header">
        <div className="chef-mvc-header-top">
          <div className="chef-mvc-brand">
            <i className="bi bi-fire chef-mvc-brand-icon" />
            <div>
              <h1>Bếp & Chế Biến</h1>
              <div className="chef-mvc-meta">
                {data.staff.branchName} - Nhân viên bếp: {data.staff.name}
              </div>
            </div>
          </div>
            <div className="chef-mvc-actions">
              <div className="chef-tab-pills" role="tablist" aria-label="Điều hướng bếp">
              <button
                type="button"
                className={activeTab === "orders" ? "tab-pill active" : "tab-pill"}
                onClick={() => setActiveTab("orders")}
              >
                <i className="bi bi-kanban me-2" />
                Đơn Hàng
              </button>
              <button
                type="button"
                className={activeTab === "menu" ? "tab-pill active" : "tab-pill"}
                onClick={() => setActiveTab("menu")}
              >
                <i className="bi bi-journal-text me-2" />
                Thực Đơn
              </button>
              </div>
              <div className="chef-mvc-divider" />
              <button className="ghost chef-header-button" onClick={() => setIngredientStockOpen(true)}>
                <i className="bi bi-box-seam me-2" />
                Kho nguyên liệu
              </button>
              <Link className="ghost action-link chef-header-button" to="/Staff/Chef/History">
                <i className="bi bi-clock-history me-2" />
                Lịch sử & Tài khoản
            </Link>
            <button className="ghost chef-logout-button" onClick={() => void onLogout()}>
              <i className="bi bi-box-arrow-right" />
            </button>
          </div>
        </div>
      </section>

      {message ? <div className="success-box">{message}</div> : null}
      {error ? <div className="error-box">{error}</div> : null}

      {activeTab === "orders" ? (
        <section className="board-grid">
          <OrderColumn
            title="Chờ chế biến"
            tone="secondary"
            orders={data.pendingOrders}
            actionLabel="Bắt đầu nấu"
            action={(orderId) => act(() => chefApi.startOrder(orderId))}
            secondaryLabel="Hủy"
            secondaryAction={(orderId, orderCode) => {
              setCancelEditor({ orderId, orderCode, reason: "" });
            }}
            onOpenIngredients={(dishId, customerNote) => void openIngredients(dishId, customerNote)}
          />
          <OrderColumn
            title="Đang chế biến"
            tone="primary"
            orders={data.preparingOrders}
            actionLabel="Hoàn thành"
            action={(orderId) => act(() => chefApi.readyOrder(orderId))}
            secondaryLabel="Hủy đơn"
            secondaryAction={(orderId, orderCode) => {
              setCancelEditor({ orderId, orderCode, reason: "" });
            }}
            onOpenIngredients={(dishId, customerNote) => void openIngredients(dishId, customerNote)}
          />
          <OrderColumn
            title="Sẵn sàng"
            tone="success"
            orders={data.readyOrders}
            secondaryLabel="Hủy đơn"
            secondaryAction={(orderId, orderCode) => {
              setCancelEditor({ orderId, orderCode, reason: "" });
            }}
            onOpenIngredients={(dishId, customerNote) => void openIngredients(dishId, customerNote)}
          />
        </section>
      ) : null}

      {activeTab === "menu" ? (
        <section className="panel chef-menu-panel">
          <div className="chef-menu-toolbar">
            <div>
              <h2>Thực đơn hôm nay</h2>
              <p className="muted chef-menu-subtitle">
                {data.menu.branchName} | {formatShortDateTime(`${data.menu.menuDate}T00:00:00`)}
              </p>
            </div>
            <div className="chef-chip-row">
              <span className="soft-badge info">{data.menu.branchName}</span>
              <span className="soft-badge primary">{data.menu.dishes.length} món</span>
              <span className="soft-badge success">{data.menu.dishes.filter((dish) => dish.available).length} đang bán</span>
              <button className="chef-primary-button chef-menu-add-button" onClick={() => openCreateDishModal()}>
                <i className="bi bi-plus-circle me-2" />
                Thêm món
              </button>
            </div>
          </div>
          <div className="chef-menu-filters">
            <input
              type="text"
              value={dishSearch}
              onChange={(event) => setDishSearch(event.target.value)}
              placeholder="Tìm món theo tên..."
            />
            <select value={dishStatusFilter} onChange={(event) => setDishStatusFilter(event.target.value as "ALL" | "AVAILABLE" | "PAUSED")}>
              <option value="ALL">Tất cả trạng thái</option>
              <option value="AVAILABLE">Đang bán</option>
              <option value="PAUSED">Tạm ngưng bán</option>
            </select>
            <select value={dishSpecialFilter} onChange={(event) => setDishSpecialFilter(event.target.value as "ALL" | "SPECIAL" | "NORMAL")}>
              <option value="ALL">Tất cả loại</option>
              <option value="SPECIAL">Món đặc biệt</option>
              <option value="NORMAL">Món thường</option>
            </select>
          </div>
          <div className="menu-grid">
            {filteredMenuDishes.map((dish) => (
              <article
                key={dish.dishId}
                className="dish-card"
                data-dish-id={dish.dishId}
                data-name={dish.name.toLowerCase()}
                data-available={dish.available ? "true" : "false"}
                data-special={dish.isDailySpecial ? "true" : "false"}
              >
                {dish.image ? (
                  <img className="dish-img" src={dish.image} alt={dish.name} />
                ) : (
                  <div className="dish-img dish-img-placeholder">
                    <i className="bi bi-image" />
                  </div>
                )}
                <div className="dish-body">
                  <h5 className="dish-title" title={dish.name}>
                    {dish.name}
                    {dish.isDailySpecial ? <span className="badge badge-special ms-2">Đặc biệt</span> : null}
                  </h5>
                  <div className="d-flex justify-content-between align-items-center mb-2">
                    <span className="dish-price">{dish.price.toLocaleString("vi-VN")} đ</span>
                    <span className="badge bg-light text-dark border">{dish.unit || "Phần"}</span>
                  </div>
                  <div className="d-flex justify-content-between align-items-center mt-3">
                    <span className={`badge ${dish.available ? "bg-success" : "bg-secondary"}`}>
                      {dish.available ? "Đang bán" : "Tạm ngưng bán"}
                    </span>
                    <div className="btn-group">
                      {dish.available ? (
                        <button className="btn btn-sm btn-outline-danger" onClick={() => void act(() => chefApi.setDishAvailability(dish.dishId, false))}>
                          <i className="bi bi-pause-circle" /> Tạm ngưng bán
                        </button>
                      ) : (
                        <button className="btn btn-sm btn-outline-success" onClick={() => void act(() => chefApi.setDishAvailability(dish.dishId, true))}>
                          <i className="bi bi-play-circle" /> Bán
                        </button>
                      )}
                      <button className="btn btn-sm btn-outline-secondary" onClick={() => void openIngredients(dish.dishId)}>
                        <i className="bi bi-list-ul" /> Thành phần
                      </button>
                    </div>
                  </div>
                  <div className="mt-2 text-end">
                    <button className="btn btn-sm btn-outline-primary" onClick={() => openEditDishModal(dish)}>
                      <i className="bi bi-pencil-square" /> Sửa
                    </button>
                  </div>
                </div>
              </article>
            ))}
          </div>
          {filteredMenuDishes.length === 0 ? (
            <div className="kanban-empty-state chef-menu-empty">
              <i className="bi bi-journal-x" />
              <p>Không có món nào phù hợp với bộ lọc hiện tại.</p>
            </div>
          ) : null}
        </section>
      ) : null}

      {dishEditor ? (
        <section className="modal-backdrop" onClick={() => setDishEditor(null)}>
          <div className="modal-card chef-modal-card chef-dish-editor-modal" onClick={(e) => e.stopPropagation()}>
            <div className="panel-head chef-modal-head">
              <div>
                <h2>{dishEditor.mode === "create" ? "Thêm Món Mới" : "Sửa Món"}</h2>
              </div>
              <button className="ghost" onClick={() => setDishEditor(null)}>Đóng</button>
            </div>

            <div className="chef-dish-editor-body">
              <div className="chef-dish-editor-form">
                <div className="chef-dish-editor-media">
                  <label>
                    <span>Hình ảnh món ăn</span>
                    <input
                      type="text"
                      readOnly
                      value={dishEditor.draft.imageFile?.name ?? dishEditor.draft.image ?? ""}
                      placeholder="Chọn file hình trên máy"
                      onClick={() => {
                        void (async () => {
                          const imageFile = await pickDishImage();
                          if (!imageFile) return;
                          setDishEditor((current) => (current
                            ? { ...current, draft: { ...current.draft, imageFile } }
                            : current));
                        })();
                      }}
                    />
                  </label>
                  <div className="chef-form-text">Chọn file hình mới nếu muốn thay đổi.</div>
                  <div className="chef-dish-editor-preview-wrap">
                    {dishEditor.draft.imageFile ? (
                      <img
                        className="chef-dish-editor-preview"
                        src={URL.createObjectURL(dishEditor.draft.imageFile)}
                        alt={dishEditor.draft.name || "Ảnh xem trước món ăn"}
                      />
                    ) : dishEditor.draft.image ? (
                      <img className="chef-dish-editor-preview" src={dishEditor.draft.image} alt={dishEditor.draft.name || "Ảnh món ăn"} />
                    ) : (
                      <div className="chef-dish-editor-placeholder">
                        <i className="bi bi-image" />
                        <span>Preview</span>
                      </div>
                    )}
                  </div>
                </div>

                <div className="chef-dish-editor-main">
                  <label>
                    <span>Tên món</span>
                    <input
                      value={dishEditor.draft.name}
                      onChange={(e) => setDishEditor((current) => (current
                        ? { ...current, draft: { ...current.draft, name: e.target.value } }
                        : current))}
                      placeholder="Nhập tên món ăn"
                    />
                  </label>

                  <div className="chef-form-row">
                    <label>
                      <span>Giá</span>
                      <input
                        type="number"
                        min="0"
                        step="1000"
                        value={dishEditor.draft.price}
                        onChange={(e) => setDishEditor((current) => (current
                          ? { ...current, draft: { ...current.draft, price: e.target.value === "" ? "" : Number(e.target.value) } }
                          : current))}
                      />
                    </label>
                    <label>
                      <span>Đơn vị</span>
                      <select
                        value={dishEditor.draft.unit ?? DISH_UNIT_OPTIONS[0]}
                        onChange={(e) => setDishEditor((current) => (current
                          ? { ...current, draft: { ...current.draft, unit: e.target.value } }
                          : current))}
                      >
                        {DISH_UNIT_OPTIONS.map((unit) => (
                          <option key={unit} value={unit}>
                            {unit}
                          </option>
                        ))}
                      </select>
                    </label>
                  </div>

                  <label>
                    <span>Danh mục</span>
                    <select
                      value={dishEditor.draft.categoryId}
                      onChange={(e) => setDishEditor((current) => (current
                        ? { ...current, draft: { ...current.draft, categoryId: Number(e.target.value) } }
                        : current))}
                    >
                      <option value="">-- Chọn danh mục --</option>
                      {categories.map((category) => (
                        <option key={category.categoryId} value={category.categoryId}>
                          {category.name}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label>
                    <span>Mô tả</span>
                    <textarea
                      rows={4}
                      value={dishEditor.draft.description ?? ""}
                      onChange={(e) => setDishEditor((current) => (current
                        ? { ...current, draft: { ...current.draft, description: e.target.value } }
                        : current))}
                    />
                  </label>

                  <div className="chef-check-grid chef-check-grid-mvc">
                    <label className="checkbox-inline">
                      <input
                        type="checkbox"
                        checked={dishEditor.draft.available}
                        onChange={(e) => setDishEditor((current) => (current
                          ? { ...current, draft: { ...current.draft, available: e.target.checked } }
                          : current))}
                      />
                      <span>Đang bán</span>
                    </label>
                    <label className="checkbox-inline">
                      <input
                        type="checkbox"
                        checked={dishEditor.draft.isVegetarian}
                        onChange={(e) => setDishEditor((current) => (current
                          ? { ...current, draft: { ...current.draft, isVegetarian: e.target.checked } }
                          : current))}
                      />
                      <span>Món chay</span>
                    </label>
                    <label className="checkbox-inline">
                      <input
                        type="checkbox"
                        checked={dishEditor.draft.isDailySpecial}
                        onChange={(e) => setDishEditor((current) => (current
                          ? { ...current, draft: { ...current.draft, isDailySpecial: e.target.checked } }
                          : current))}
                      />
                      <span>Món đặc biệt trong ngày</span>
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div className="header-actions chef-modal-actions">
              {dishEditor.mode === "create" ? (
                <button className="ghost" onClick={resetDishEditorDraft}>Reset</button>
              ) : null}
              <button className="ghost" onClick={() => setDishEditor(null)}>Đóng</button>
              <button onClick={() => void saveDishEditor()}>
                {dishEditor.mode === "create" ? "Thêm Món" : "Lưu thay đổi"}
              </button>
            </div>
          </div>
        </section>
      ) : null}

      {ingredientEditor ? (
        <section className="modal-backdrop" onClick={() => setIngredientEditor(null)}>
          <div className="modal-card chef-modal-card chef-compact-modal chef-ingredients-modal" onClick={(e) => e.stopPropagation()}>
            <div className="panel-head chef-modal-head">
              <div>
                <h2>Thành phần món: {ingredientEditor.dishName}</h2>
                <p className="muted">Quản lý định lượng nguyên liệu cho từng phần món.</p>
              </div>
              <button className="ghost" onClick={() => setIngredientEditor(null)}>Đóng</button>
            </div>
            {ingredientEditor.customerNote?.trim() ? (
              <div className="inline-filter-card chef-modal-section">
                <div>
                  <strong>Ghi chú từ khách hàng</strong>
                  <div className="muted">{ingredientEditor.customerNote}</div>
                </div>
                <span className="soft-badge warning">Điều chỉnh khi chế biến</span>
              </div>
            ) : null}
            <div className="inline-filter-card chef-modal-section">
              <div>
                <strong>Công thức món</strong>
                <div className="muted">Cập nhật số lượng nguyên liệu cần dùng cho một phần món.</div>
              </div>
              <div className="chef-chip-row">
                <span className="soft-badge info">{ingredientEditor.items.length} nguyên liệu</span>
                <span className="soft-badge success">{ingredientEditor.items.filter((item) => item.isActive).length} đang hoạt động</span>
              </div>
            </div>
            <div className="ingredient-editor">
              {ingredientEditor.items.map((item, index) => (
                <label key={item.ingredientId} className="ingredient-line">
                  <div className="ingredient-meta">
                    <span>{item.name} ({item.unit})</span>
                    <small>Tồn kho: {item.currentStock.toLocaleString("vi-VN")} {item.unit}</small>
                  </div>
                  <input
                    type="number"
                    min="0"
                    step="0.1"
                    value={item.quantityPerDish}
                    onChange={(e) => {
                      const next = [...ingredientEditor.items];
                      next[index] = { ...item, quantityPerDish: Number(e.target.value) };
                      setIngredientEditor({ ...ingredientEditor, items: next });
                    }}
                  />
                </label>
              ))}
            </div>
            <div className="header-actions chef-modal-actions">
              <button className="ghost" onClick={() => setIngredientEditor(null)}>Đóng</button>
              <button onClick={() => void saveIngredients()}>Lưu thành phần</button>
            </div>
          </div>
        </section>
      ) : null}

      {ingredientStockOpen ? (
        <section className="modal-backdrop" onClick={() => setIngredientStockOpen(false)}>
          <div className="modal-card chef-modal-card chef-stock-modal" onClick={(e) => e.stopPropagation()}>
            <div className="panel-head chef-modal-head">
              <div>
                <h2>Tồn kho nguyên liệu</h2>
                <p className="muted">Thông tin nguyên liệu hiện tại của {data.staff.branchName}</p>
              </div>
              <button className="ghost" onClick={() => setIngredientStockOpen(false)}>Đóng</button>
            </div>
            <div className="chef-modal-section">
              <div className="chef-inline-alert chef-inline-alert-info">
                Thông tin tồn kho hiện tại để bếp cân đối khi nhận đơn. Những nguyên liệu dưới ngưỡng sẽ được tô nổi.
              </div>
              <div className="chef-stock-filter-grid">
                <input
                  value={ingredientStockSearch}
                  onChange={(e) => setIngredientStockSearch(e.target.value)}
                  placeholder="Tìm kiếm theo tên nguyên liệu..."
                />
                <label className="checkbox-inline chef-stock-checkbox">
                  <input
                    type="checkbox"
                    checked={onlyLowStock}
                    onChange={(e) => setOnlyLowStock(e.target.checked)}
                  />
                  <span>Chỉ hiện nguyên liệu sắp hết</span>
                </label>
              </div>
            </div>
            <div className="table-scroll chef-stock-table-scroll">
              <table className="staff-table">
                <thead>
                  <tr>
                    <th>Tên nguyên liệu</th>
                    <th>Đơn vị</th>
                    <th>Tồn hiện tại</th>
                    <th>Ngưỡng cảnh báo</th>
                  </tr>
                </thead>
                <tbody>
                  {ingredientStockRows.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="muted table-empty">
                        Không có nguyên liệu phù hợp với bộ lọc đang chọn.
                      </td>
                    </tr>
                  ) : (
                    ingredientStockRows.map((item) => {
                      const isLowStock = item.reorderLevel > 0 && item.currentStock <= item.reorderLevel;
                      return (
                        <tr key={item.ingredientId} className={isLowStock ? "chef-stock-row-low" : undefined}>
                          <td>{item.name}</td>
                          <td>{item.unit}</td>
                          <td>{item.currentStock.toLocaleString("vi-VN")}</td>
                          <td>{item.reorderLevel.toLocaleString("vi-VN")}</td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </section>
      ) : null}

      {cancelEditor ? (
        <section className="modal-backdrop" onClick={() => setCancelEditor(null)}>
          <div className="modal-card chef-modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="panel-head chef-modal-head">
              <div>
                <h2>Hủy đơn hàng</h2>
              </div>
              <button className="ghost" onClick={() => setCancelEditor(null)}>Đóng</button>
            </div>
            <div className="chef-modal-section">
              <div className="alert alert-warning small">
                Vui lòng nhập lý do hủy đơn. Thông tin này sẽ được lưu lại trong lịch sử đơn hàng.
              </div>
              <label className="stack compact">
                <span>Lý do hủy đơn</span>
                <textarea
                  rows={4}
                  maxLength={500}
                  value={cancelEditor.reason}
                  onChange={(e) => setCancelEditor({ ...cancelEditor, reason: e.target.value })}
                  placeholder="Ví dụ: Khách yêu cầu hủy, món hết nguyên liệu..."
                />
              </label>
            </div>
            <div className="header-actions chef-modal-actions">
              <button className="ghost" onClick={() => setCancelEditor(null)}>Đóng</button>
              <button onClick={() => void submitCancel()}>
                <i className="bi bi-x-circle me-1" />
                Xác nhận hủy
              </button>
            </div>
          </div>
        </section>
      ) : null}
    </main>
  );
}

type OrderColumnProps = {
  title: string;
  tone: "secondary" | "primary" | "success";
  orders: ChefOrderDto[];
  actionLabel?: string;
  action?: (orderId: number) => Promise<void>;
  secondaryLabel?: string;
  secondaryAction?: (orderId: number, orderCode: string) => void;
  onOpenIngredients: (dishId: number, customerNote?: string | null) => void;
};

function OrderColumn({ title, tone, orders, actionLabel, action, secondaryLabel, secondaryAction, onOpenIngredients }: OrderColumnProps) {
  function formatOrderTime(value: string) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
  }

  const iconClass =
    tone === "secondary"
      ? "bi bi-hourglass-split"
      : tone === "primary"
        ? "bi bi-fire"
        : "bi bi-bell";

  const emptyMessage =
    tone === "secondary"
      ? "Không có đơn chờ"
      : tone === "primary"
        ? "Không có đơn đang chế biến"
        : "Không có món chờ phục vụ";

  return (
    <section className={`panel order-column order-column-${tone}`}>
      <div className={`kanban-header kanban-header-${tone}`}>
        <span className="kanban-title">
          <i className={iconClass} />
          {title}
        </span>
        <span className={`kanban-count kanban-count-${tone}`}>{orders.length}</span>
      </div>
      <div className="order-list">
        {orders.length === 0 ? (
          <div className="kanban-empty-state">
            <i className="bi bi-check2-circle" />
            <p>{emptyMessage}</p>
          </div>
        ) : null}
        {orders.map((order) => (
          <article
            key={order.orderId}
            className={`order-card ${
              tone === "primary" ? "priority-high" : tone === "success" ? "priority-success" : "priority-normal"
            }`}
          >
            <div className="order-header">
              <span className={`table-badge ${tone === "success" ? "table-badge-success" : ""}`}>
                {order.tableName || `Bàn ${order.tableId ?? "?"}`}
              </span>
              <span className="order-time">
                <i className="bi bi-clock me-1" />
                {formatOrderTime(order.orderTime)}
              </span>
            </div>
            <div className="order-code-label">#{order.orderCode || `ORD${order.orderId}`}</div>
            <div className="order-items">
              {order.items.map((item) => (
                <div key={item.itemId} className="order-item">
                  <div className="order-item-layout">
                    <span className="item-qty">{item.quantity}</span>
                    <div className="order-item-content">
                      <strong className="item-name">{item.dishName}</strong>
                      {item.note?.trim() ? <small className="item-note">Note: {item.note}</small> : null}
                    </div>
                  </div>
                  <button
                    className="ghost note-action-button"
                    onClick={() => onOpenIngredients(item.dishId, item.note || "")}
                  >
                    Thành phần
                  </button>
                </div>
              ))}
            </div>
            <div className="order-action-stack">
              {actionLabel && action ? (
                <button className="btn-action-primary" onClick={() => void action(order.orderId)}>
                  {actionLabel}
                </button>
              ) : null}
              {tone === "success" ? (
                <div className="order-ready-alert">
                  <i className="bi bi-bell-fill" />
                  <div>
                    <strong>Đã báo phục vụ</strong>
                  </div>
                </div>
              ) : null}
              {secondaryLabel && secondaryAction ? (
                <button
                  className="btn-action-danger"
                  onClick={() => secondaryAction(order.orderId, order.orderCode || `ORD${order.orderId}`)}
                >
                  {secondaryLabel}
                </button>
              ) : null}
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

