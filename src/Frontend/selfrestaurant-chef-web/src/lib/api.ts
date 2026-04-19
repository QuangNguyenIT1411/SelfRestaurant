import type {
  ApiError,
  ChefCategoryDto,
  ChefDashboardDto,
  ChefDishIngredientsDto,
  ChefSaveDishIngredientItemDto,
  ChefUpsertDishPayload,
  StaffForgotPasswordResultDto,
  StaffSessionDto,
} from "./types";

const jsonHeaders = { "Content-Type": "application/json" };

type ApiIssue = {
  ingredientName?: string;
  requiredQuantity?: number;
  availableQuantity?: number;
  unit?: string | null;
};

const API_TEXT_MAP: Record<string, string> = {
  "Ban can dang nhap bang tai khoan bep.": "Bạn cần đăng nhập bằng tài khoản bếp.",
  "Da cap nhat thong tin mon an.": "Đã cập nhật thông tin món ăn.",
  "Da them mon moi.": "Đã thêm món mới.",
  "Da luu nguyen lieu mon.": "Đã lưu nguyên liệu món.",
  "Nguyen lieu": "Nguyên liệu",
  "Phan": "Phần",
  "ÄÃ£ cÃ³ lá»—i xáº£y ra.": "Đã có lỗi xảy ra.",
  "NguyÃªn liá»‡u": "Nguyên liệu",
  "cáº§n": "cần",
  "hiá»‡n cÃ²n": "hiện còn",
  "Pháº§n": "Phần",
};

function normalizeApiText(value?: string | null): string {
  if (!value) return "";

  let normalized = value.replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
    String.fromCharCode(Number.parseInt(hex, 16)),
  );

  for (const [source, target] of Object.entries(API_TEXT_MAP)) {
    normalized = normalized.split(source).join(target);
  }

  return normalized.trim();
}

function formatApiError(error: ApiError | null): string {
  const baseMessage = normalizeApiText(error?.message) || "Đã có lỗi xảy ra.";
  const issues = Array.isArray((error as { issues?: ApiIssue[] } | null)?.issues)
    ? ((error as { issues?: ApiIssue[] }).issues ?? [])
    : [];

  if (issues.length === 0) {
    return baseMessage;
  }

  const details = issues
    .map((issue) => {
      const ingredientName = normalizeApiText(issue.ingredientName) || "Nguyên liệu";
      const required = typeof issue.requiredQuantity === "number"
        ? issue.requiredQuantity.toLocaleString("vi-VN")
        : "?";
      const available = typeof issue.availableQuantity === "number"
        ? issue.availableQuantity.toLocaleString("vi-VN")
        : "?";
      const normalizedUnit = normalizeApiText(issue.unit);
      const unit = normalizedUnit ? ` ${normalizedUnit}` : "";
      return `- ${ingredientName}: cần ${required}${unit}, hiện còn ${available}${unit}`;
    })
    .join("\n");

  return `${baseMessage}\n${details}`;
}

async function request<T>(input: string, init?: RequestInit): Promise<T> {
  const response = await fetch(input, {
    credentials: "include",
    headers: init?.body ? { ...jsonHeaders, ...(init.headers ?? {}) } : init?.headers,
    ...init,
  });

  const text = await response.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }
  if (!response.ok) {
    if (payload && typeof payload === "object") {
      const error = payload as ApiError | null;
      throw new Error(formatApiError(error) || `Request failed: ${response.status}`);
    }
    throw new Error(normalizeApiText(String(payload)) || `Request failed: ${response.status}`);
  }
  return payload as T;
}

async function requestForm<T>(input: string, formData: FormData, method = "PUT"): Promise<T> {
  const response = await fetch(input, {
    method,
    body: formData,
    credentials: "include",
  });

  const text = await response.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }
  if (!response.ok) {
    if (payload && typeof payload === "object") {
      const error = payload as ApiError | null;
      throw new Error(formatApiError(error) || `Request failed: ${response.status}`);
    }
    throw new Error(normalizeApiText(String(payload)) || `Request failed: ${response.status}`);
  }
  return payload as T;
}

export const chefApi = {
  getSession: () => request<StaffSessionDto>("/api/gateway/staff/session"),
  login: (username: string, password: string) =>
    request<{ success: boolean; nextPath?: string; session: StaffSessionDto }>("/api/gateway/staff/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),
  forgotPassword: (email: string) =>
    request<StaffForgotPasswordResultDto>("/api/gateway/staff/auth/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email }),
    }),
  validateResetPasswordToken: (token: string) =>
    request<{ valid: true }>(`/api/gateway/staff/auth/reset-password/validate?token=${encodeURIComponent(token)}`),
  resetPassword: (payload: { token: string; newPassword: string; confirmPassword: string }) =>
    request<{ success: boolean; message: string; nextPath?: string }>("/api/gateway/staff/auth/reset-password", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  logout: () =>
    request<{ success: boolean; nextPath?: string }>("/api/gateway/staff/auth/logout", {
      method: "POST",
      body: JSON.stringify({}),
    }),
  getDashboard: () => request<ChefDashboardDto>("/api/gateway/staff/chef/dashboard"),
  getCategories: () => request<ChefCategoryDto[]>("/api/gateway/staff/chef/categories"),
  startOrder: (orderId: number) =>
    request<{ success: boolean; message: string }>(`/api/gateway/staff/chef/orders/${orderId}/start`, {
      method: "POST",
      body: JSON.stringify({}),
    }),
  readyOrder: (orderId: number) =>
    request<{ success: boolean; message: string }>(`/api/gateway/staff/chef/orders/${orderId}/ready`, {
      method: "POST",
      body: JSON.stringify({}),
    }),
  cancelOrder: (orderId: number, reason: string) =>
    request<{ success: boolean; message: string }>(`/api/gateway/staff/chef/orders/${orderId}/cancel`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    }),
  updateItemNote: (orderId: number, itemId: number, note: string, append = true) =>
    request<{ success: boolean; message: string }>(`/api/gateway/staff/chef/orders/${orderId}/items/${itemId}/note`, {
      method: "PATCH",
      body: JSON.stringify({ note, append }),
    }),
  getDishIngredients: (dishId: number) =>
    request<ChefDishIngredientsDto>(`/api/gateway/staff/chef/dishes/${dishId}/ingredients`),
  updateAccount: (payload: { name: string; phone: string; email?: string }) =>
    request<StaffSessionDto["staff"]>("/api/gateway/staff/chef/account", {
      method: "PUT",
      body: JSON.stringify(payload),
    }),
  changePassword: (payload: { currentPassword: string; newPassword: string; confirmPassword: string }) =>
    request<{ success: boolean; message: string }>("/api/gateway/staff/chef/change-password", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  saveDishIngredients: (dishId: number, items: ChefDishIngredientsDto["items"]) => {
    const payload: ChefSaveDishIngredientItemDto[] = items.map((item) => ({
      ingredientId: item.ingredientId,
      quantityPerDish: item.quantityPerDish,
    }));
    return request<ChefDishIngredientsDto>(`/api/gateway/staff/chef/dishes/${dishId}/ingredients`, {
      method: "PUT",
      body: JSON.stringify({ items: payload }),
    });
  },
  setDishAvailability: (dishId: number, available: boolean) =>
    request<{ success: boolean; message: string; available: boolean }>(
      `/api/gateway/staff/chef/dishes/${dishId}/availability`,
      {
        method: "POST",
        body: JSON.stringify({ available }),
      },
    ),
  updateDishImage: (dishId: number, imageFile: File) => {
    const form = new FormData();
    form.append("imageFile", imageFile);
    return requestForm<{ success: boolean; message: string; image?: string | null }>(
      `/api/gateway/staff/chef/dishes/${dishId}/image`,
      form,
      "PUT",
    );
  },
  createDish: (payload: ChefUpsertDishPayload) => {
    const form = new FormData();
    form.append("name", payload.name);
    form.append("price", String(payload.price));
    form.append("categoryId", String(payload.categoryId));
    form.append("description", payload.description ?? "");
    form.append("unit", payload.unit ?? "");
    form.append("image", payload.image ?? "");
    form.append("isVegetarian", String(payload.isVegetarian));
    form.append("isDailySpecial", String(payload.isDailySpecial));
    form.append("available", String(payload.available));
    form.append("isActive", String(payload.isActive ?? true));
    if (payload.imageFile) {
      form.append("imageFile", payload.imageFile);
    }
    return requestForm<{ success: boolean; message: string }>("/api/gateway/staff/chef/dishes", form, "POST");
  },
  updateDish: (dishId: number, payload: ChefUpsertDishPayload) => {
    const form = new FormData();
    form.append("name", payload.name);
    form.append("price", String(payload.price));
    form.append("categoryId", String(payload.categoryId));
    form.append("description", payload.description ?? "");
    form.append("unit", payload.unit ?? "");
    form.append("image", payload.image ?? "");
    form.append("isVegetarian", String(payload.isVegetarian));
    form.append("isDailySpecial", String(payload.isDailySpecial));
    form.append("available", String(payload.available));
    form.append("isActive", String(payload.isActive ?? true));
    if (payload.imageFile) {
      form.append("imageFile", payload.imageFile);
    }
    return requestForm<{ success: boolean; message: string }>(
      `/api/gateway/staff/chef/dishes/${dishId}`,
      form,
      "PUT",
    );
  },
};
