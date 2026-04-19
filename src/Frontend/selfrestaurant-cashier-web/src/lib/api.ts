import type {
  ApiError,
  CashierAccountDto,
  CashierCheckoutResultDto,
  CashierDashboardDto,
  CashierHistoryDto,
  CashierReportScreenDto,
  StaffSessionDto,
} from "./types";

const jsonHeaders = { "Content-Type": "application/json" };

async function request<T>(input: string, init?: RequestInit): Promise<T> {
  const response = await fetch(input, {
    credentials: "include",
    headers: init?.body ? { ...jsonHeaders, ...(init.headers ?? {}) } : init?.headers,
    ...init,
  });

  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const error = payload as ApiError | null;
    throw new Error(error?.message ?? `Request failed: ${response.status}`);
  }
  return payload as T;
}

export const cashierApi = {
  getSession: () => request<StaffSessionDto>("/api/gateway/staff/cashier/session"),
  login: (username: string, password: string) =>
    request<{ success: boolean; nextPath?: string; session: StaffSessionDto }>("/api/gateway/staff/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),
  logout: () => request<{ success: boolean; nextPath?: string }>("/api/gateway/staff/cashier/auth/logout", { method: "POST", body: JSON.stringify({}) }),
  getDashboard: () => request<CashierDashboardDto>("/api/gateway/staff/cashier/dashboard"),
  getHistory: () => request<CashierHistoryDto>("/api/gateway/staff/cashier/history"),
  getReport: (date?: string) => request<CashierReportScreenDto>(`/api/gateway/staff/cashier/report${date ? `?date=${date}` : ""}`),
  checkout: (orderId: number, payload: { discount?: number; pointsUsed?: number; paymentMethod?: string; paymentAmount?: number }) =>
    request<CashierCheckoutResultDto>(`/api/gateway/staff/cashier/orders/${orderId}/checkout`, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  updateAccount: (payload: { name: string; phone: string; email?: string }) =>
    request<CashierAccountDto>("/api/gateway/staff/cashier/account", { method: "PUT", body: JSON.stringify(payload) }),
  changePassword: (payload: { currentPassword: string; newPassword: string; confirmPassword: string }) =>
    request<{ success: boolean; message: string }>("/api/gateway/staff/cashier/change-password", { method: "POST", body: JSON.stringify(payload) }),
};
