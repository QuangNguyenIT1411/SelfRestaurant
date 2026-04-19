import type {
  ActiveOrderResponse,
  AddOrderItemPayload,
  ApiErrorResponse,
  BranchDto,
  BranchTableDto,
  BranchTablesResponse,
  CustomerDashboardDto,
  CustomerForgotPasswordResultDto,
  CustomerMenuScreenDto,
  CustomerMenuRecommendationsDto,
  CustomerOrderHistoryDto,
  CustomerProfileDto,
  CustomerReadyNotificationsDto,
  CustomerSessionDto,
  DevResetResponse,
  LoyaltyScanResponse,
} from "./types";

function decodeEscapedUnicode(value?: string | null) {
  if (!value) return value ?? "";
  return value.replace(/\\u([0-9a-fA-F]{4})/g, (_, hex: string) =>
    String.fromCharCode(Number.parseInt(hex, 16)),
  );
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
    ...init,
  });

  if (!response.ok) {
    const contentType = response.headers.get("content-type") ?? "";
    if (contentType.includes("application/json")) {
      const error = (await response.json()) as ApiErrorResponse;
      throw new Error(decodeEscapedUnicode(error.message) || error.code || "Request failed");
    }
    throw new Error(decodeEscapedUnicode(await response.text()));
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}

export const api = {
  getSession: () => request<CustomerSessionDto>("/api/gateway/customer/session"),
  syncSessionFromActiveOrder: () => request<CustomerSessionDto>("/api/gateway/customer/session/sync-active-order", { method: "POST" }),
  devResetTestState: () => request<DevResetResponse>("/api/gateway/customer/dev/reset-test-state", { method: "POST" }),
  validateResetPasswordToken: (token: string) => request<{ valid: true }>(`/api/gateway/customer/auth/reset-password/validate?token=${encodeURIComponent(token)}`),
  login: (payload: { username: string; password: string }) => request<{ success: true; session: CustomerSessionDto; nextPath: string }>("/api/gateway/customer/auth/login", { method: "POST", body: JSON.stringify(payload) }),
  register: (payload: { name: string; username: string; password: string; phoneNumber: string; email?: string; gender?: string; dateOfBirth?: string | null; address?: string }) => request<{ success: true; message: string; nextPath: string }>("/api/gateway/customer/auth/register", { method: "POST", body: JSON.stringify(payload) }),
  logout: () => request<{ success: true; nextPath: string }>("/api/gateway/customer/auth/logout", { method: "POST" }),
  forgotPassword: (payload: { usernameOrEmailOrPhone: string }) => request<CustomerForgotPasswordResultDto>("/api/gateway/customer/auth/forgot-password", { method: "POST", body: JSON.stringify(payload) }),
  resetPassword: (payload: { token: string; newPassword: string; confirmPassword: string }) => request<{ success: true; message: string; nextPath: string }>("/api/gateway/customer/auth/reset-password", { method: "POST", body: JSON.stringify(payload) }),
  changePassword: (payload: { currentPassword: string; newPassword: string; confirmPassword: string }) => request<{ success: true; message: string }>("/api/gateway/customer/auth/change-password", { method: "POST", body: JSON.stringify(payload) }),
  getBranches: () => request<BranchDto[]>("/api/gateway/customer/branches"),
  getBranchTables: async (branchId: number) => {
    const response = await fetch(`/api/gateway/customer/branches/${branchId}/tables`, {
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const contentType = response.headers.get("content-type") ?? "";
      if (contentType.includes("application/json")) {
        const error = (await response.json()) as ApiErrorResponse;
        throw new Error(decodeEscapedUnicode(error.message) || error.code || "Request failed");
      }

      throw new Error(decodeEscapedUnicode(await response.text()));
    }

    return (await response.json()) as BranchTablesResponse;
  },
  getTableByQr: (code: string) => request<BranchTableDto>(`/api/gateway/customer/tables/qr/${encodeURIComponent(code)}`),
  setContextTable: (payload: { tableId: number; branchId: number }) => request("/api/gateway/customer/context/table", { method: "POST", body: JSON.stringify(payload) }),
  clearContextTable: () => request<{ success: true }>("/api/gateway/customer/context/table", { method: "DELETE" }),
  resetCurrentTable: () => request<{ success: true; message: string }>("/api/gateway/customer/context/table/reset", { method: "POST" }),
  getContextTable: () => request("/api/gateway/customer/context"),
  getProfile: () => request<CustomerProfileDto>("/api/gateway/customer/profile"),
  updateProfile: (payload: { username: string; name: string; phoneNumber: string; email?: string | null; gender?: string | null; dateOfBirth?: string | null; address?: string | null }) => request<CustomerProfileDto>("/api/gateway/customer/profile", { method: "PUT", body: JSON.stringify(payload) }),
  getMenu: () => request<CustomerMenuScreenDto>("/api/gateway/customer/menu"),
  getMenuRecommendations: (cartDishIds?: number[]) => {
    const params = new URLSearchParams();
    for (const dishId of cartDishIds ?? []) {
      if (dishId > 0) {
        params.append("cartDishIds", String(dishId));
      }
    }

    const suffix = params.size > 0 ? `?${params.toString()}` : "";
    return request<CustomerMenuRecommendationsDto>(`/api/gateway/customer/menu/recommendations${suffix}`);
  },
  getOrderHistory: (take = 20) => request<CustomerOrderHistoryDto[]>(`/api/gateway/customer/orders/history?take=${take}`),
  getReadyNotifications: () => request<CustomerReadyNotificationsDto>("/api/gateway/customer/ready-notifications"),
  resolveReadyNotification: (notificationId: number) => request<{ success: true }>(`/api/gateway/customer/ready-notifications/${notificationId}/resolve`, { method: "POST" }),
  getOrder: () => request<ActiveOrderResponse | null>("/api/gateway/customer/order"),
  getOrderItems: () => request<{ success: true; orderId?: number | null; items: ActiveOrderResponse["items"]; subtotal: number }>("/api/gateway/customer/order/items"),
  addItem: (payload: { dishId: number; quantity: number; note?: string }) => request<ActiveOrderResponse | null>("/api/gateway/customer/order/items", { method: "POST", body: JSON.stringify(payload) }),
  updateItemQuantity: (itemId: number, quantity: number) => request<{ success: true }>(`/api/gateway/customer/order/items/${itemId}/quantity`, { method: "PATCH", body: JSON.stringify({ quantity }) }),
  updateItemNote: (itemId: number, note: string) => request<{ success: true }>(`/api/gateway/customer/order/items/${itemId}/note`, { method: "PATCH", body: JSON.stringify({ note }) }),
  removeItem: (itemId: number) => request<{ success: true }>(`/api/gateway/customer/order/items/${itemId}`, { method: "DELETE" }),
  submitOrder: () => request<{ success: true; message: string }>("/api/gateway/customer/order/submit", { method: "POST" }),
  submitMenuOrder: (payload: { tableId: number; branchId: number; items: AddOrderItemPayload[] }) =>
    request<{ success: true; message: string }>("/api/gateway/customer/menu/send-order-to-kitchen", { method: "POST", body: JSON.stringify(payload) }),
  confirmReceived: (orderId: number) => request<{ success: true; message: string }>(`/api/gateway/customer/order/confirm-received?orderId=${orderId}`, { method: "POST" }),
  scanLoyalty: (phoneNumber: string) => request<LoyaltyScanResponse>("/api/gateway/customer/order/scan-loyalty", { method: "POST", body: JSON.stringify({ phoneNumber }) }),
  getDashboard: () => request<CustomerDashboardDto>("/api/gateway/customer/dashboard"),
};
