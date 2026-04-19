import { FormEvent, useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { getPersistentTableContext } from "../lib/persistentTable";
import { toMvcPath } from "../lib/mvcPaths";

const text = {
  title: "Self Restaurant",
  subtitle: "Đăng nhập tài khoản khách hàng",
  username: "Tên Đăng Nhập",
  usernamePlaceholder: "Nhập tên đăng nhập",
  password: "Mật Khẩu",
  passwordPlaceholder: "Nhập mật khẩu",
  rememberMe: "Nhớ tôi",
  forgotPassword: "Quên mật khẩu?",
  submit: "Đăng Nhập",
  submitting: "Đang đăng nhập...",
  registerPrefix: "Chưa có tài khoản?",
  registerLink: "Đăng ký ngay",
  togglePassword: "Ẩn/hiện mật khẩu",
  success: "Đăng nhập thành công!",
} as const;

function resolveLoginNextPath(from: string | undefined, nextPath: string | undefined) {
  const normalizedFrom = from?.trim();
  const blockedRedirects = new Set([
    "/login",
    "/customer/login",
    "/Customer/Login",
    "/register",
    "/customer/register",
    "/Customer/Register",
    "/forgot-password",
    "/customer/forgot-password",
    "/customer/forgotpassword",
    "/Customer/ForgotPassword",
    "/reset-password",
    "/customer/reset-password",
    "/customer/resetpassword",
    "/Customer/ResetPassword",
  ]);

  if (normalizedFrom && !blockedRedirects.has(normalizedFrom)) {
    return normalizedFrom;
  }

  return nextPath ?? "/Home/Index";
}

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();
  const returnUrl = new URLSearchParams(location.search).get("returnUrl") ?? undefined;
  const flashMessage = new URLSearchParams(location.search).get("message");
  const flashType = new URLSearchParams(location.search).get("type") ?? "success";
  const session = useQuery({ queryKey: ["session"], queryFn: api.getSession });
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [dismissedFlash, setDismissedFlash] = useState(false);
  const [dismissedError, setDismissedError] = useState(false);

  const login = useMutation({
    mutationFn: api.login,
    onSuccess: async (result) => {
      await queryClient.invalidateQueries();
      await queryClient.refetchQueries({ queryKey: ["session"], type: "active" });
      const customerId = result.session.customer?.customerId;
      const savedTable = customerId ? getPersistentTableContext(customerId) : null;
      if (!result.session.tableContext && savedTable) {
        try {
          await api.setContextTable({ tableId: savedTable.tableId, branchId: savedTable.branchId });
          await queryClient.invalidateQueries({ queryKey: ["session"] });
          await queryClient.refetchQueries({ queryKey: ["session"], type: "active" });
          result = {
            ...result,
            nextPath: "/Menu/Index",
          };
        } catch {
          // Keep normal login flow if the saved table can no longer be restored.
        }
      }
      setSuccessMessage(text.success);
      const nextPath = resolveLoginNextPath((location.state as { from?: string } | null)?.from, returnUrl ?? result.nextPath);
      window.setTimeout(() => {
        window.location.assign(toMvcPath(nextPath));
      }, 1000);
    },
  });

  useEffect(() => {
    if (!session.data?.authenticated) return;
    const nextPath = returnUrl ?? "/Customer/Dashboard";
    navigate(toMvcPath(nextPath), { replace: true });
  }, [navigate, returnUrl, session.data]);

  const onSubmit = (event: FormEvent) => {
    event.preventDefault();
    login.mutate({ username, password });
  };

  return (
    <div className="auth-wrapper">
      <div className="login-container">
        <div className="login-header">
          <div className="logo">
            <i className="fas fa-utensils" />
          </div>
          <h1>{text.title}</h1>
          <p>{text.subtitle}</p>
        </div>

        <form id="login-form" className="auth-form auth-form-compact" onSubmit={onSubmit}>
          <div className="form-group">
            <label htmlFor="login-username">
              <i className="fas fa-user me-2" />
              {text.username}
            </label>
            <input
              id="login-username"
              className="form-control"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              placeholder={text.usernamePlaceholder}
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="login-password">
              <i className="fas fa-lock me-2" />
              {text.password}
            </label>
            <div className="password-toggle auth-password-toggle">
              <input
                id="login-password"
                className="form-control"
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder={text.passwordPlaceholder}
                required
              />
              <button
                type="button"
                className="auth-password-toggle-btn"
                onClick={() => setShowPassword((value) => !value)}
                aria-label={text.togglePassword}
              >
                <i className={`fas ${showPassword ? "fa-eye-slash" : "fa-eye"}`} />
              </button>
            </div>
          </div>

          <div className="form-options">
            <label className="form-check auth-checkbox">
              <input
                className="form-check-input"
                type="checkbox"
                checked={rememberMe}
                onChange={(event) => setRememberMe(event.target.checked)}
              />
              <span>{text.rememberMe}</span>
            </label>
            <div className="forgot-password">
              <Link className="secondary" to="/Customer/ForgotPassword">
                <i className="fas fa-key me-1" />
                {text.forgotPassword}
              </Link>
            </div>
          </div>

          <button className="btn btn-danger btn-login" type="submit" disabled={login.isPending || Boolean(successMessage)}>
            <i className={`fas ${login.isPending ? "fa-spinner fa-spin" : "fa-sign-in-alt"} me-2`} />
            <span>{login.isPending ? text.submitting : text.submit}</span>
          </button>

          <div className="register-link auth-links">
            {text.registerPrefix} <Link to="/Customer/Register">{text.registerLink}</Link>
          </div>

          <div id="alert-message" className="auth-inline-slot">
            {flashMessage && !dismissedFlash ? (
              <div className={`alert ${flashType === "error" ? "alert-danger" : "alert-success"} alert-dismissible fade show auth-alert`} role="alert">
                <i className={`fas ${flashType === "error" ? "fa-exclamation-circle" : "fa-check-circle"} me-2`} />
                {flashMessage}
                <button type="button" className="btn-close" aria-label="Close" onClick={() => setDismissedFlash(true)} />
              </div>
            ) : null}
            {successMessage ? (
              <div className="alert alert-success auth-alert" role="alert">
                <i className="fas fa-check-circle me-2" />
                {successMessage}
              </div>
            ) : null}
            {login.error && !dismissedError ? (
              <div className="alert alert-danger alert-dismissible fade show auth-alert" role="alert">
                <i className="fas fa-exclamation-circle me-2" />
                {(login.error as Error).message}
                <button type="button" className="btn-close" aria-label="Close" onClick={() => setDismissedError(true)} />
              </div>
            ) : null}
          </div>
        </form>
      </div>
    </div>
  );
}
