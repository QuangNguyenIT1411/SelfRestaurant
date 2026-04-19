import type { ReactNode } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import type { StaffSessionUserDto } from "../lib/types";

type Props = {
  title: string;
  description: string;
  staff?: StaffSessionUserDto | null;
  onLogout: () => Promise<void>;
  onRefresh?: (() => void | Promise<void>) | null;
  children: ReactNode;
  message?: string | null;
  error?: string | null;
};

const navSections = [
  {
    items: [
      { label: "Tổng quan", icon: "bi-grid-fill", path: "/Admin/Dashboard/Index", match: "/admin/dashboard" },
      { label: "Danh mục", icon: "bi-folder2-open", path: "/Admin/Categories/Index", match: "/admin/categories" },
      { label: "Nguyên liệu", icon: "bi-basket3-fill", path: "/Admin/Ingredients/Index", match: "/admin/ingredients" },
      { label: "Món ăn", icon: "bi-egg-fried", path: "/Admin/Dishes/Index", match: "/admin/dishes" },
      { label: "Bàn & QR", icon: "bi-grid-3x3-gap-fill", path: "/Admin/TablesQR/Index", match: "/admin/tablesqr" },
      { label: "Nhân viên", icon: "bi-people-fill", path: "/Admin/Employees/Index", match: "/admin/employees" },
      { label: "Khách hàng", icon: "bi-person-badge-fill", path: "/Admin/Customers/Index", match: "/admin/customers" },
    ],
  },
  {
    title: "Báo cáo",
    items: [
      { label: "Báo cáo", icon: "bi-graph-up-arrow", path: "/Admin/Reports/Revenue", match: "/admin/reports" },
    ],
  },
  {
    title: "Tài khoản",
    items: [
      { label: "Cài đặt", icon: "bi-gear-fill", path: "/Admin/Settings/Index", match: "/admin/settings" },
    ],
  },
];

export function AdminLayout({ title, description, staff, onLogout, onRefresh, children, message, error }: Props) {
  const location = useLocation();
  const navigate = useNavigate();
  const normalizedPath = location.pathname.toLowerCase();

  return (
    <main className="admin-shell">
      <div className="admin-layout">
        <aside className="admin-sidebar">
          <div className="sidebar-card">
            <div className="sidebar-header">
              <div className="sidebar-avatar">
                <i className="bi bi-shield-lock-fill" />
              </div>
              <div>
                <div className="sidebar-title">Admin</div>
                <div className="sidebar-subtitle">{staff?.roleName ?? "Quản trị"}</div>
              </div>
            </div>
            <div className="sidebar-links">
              {navSections.map((section) => (
                <div key={section.title ?? "main"} className="sidebar-group">
                  {section.title ? <div className="sidebar-group-title">{section.title}</div> : null}
                  {section.items.map((item) => (
                    <button
                      key={item.path}
                      className={`sidebar-link ${normalizedPath.startsWith(item.match) ? "active" : ""}`}
                      onClick={() => navigate(item.path)}
                    >
                      <i className={`bi ${item.icon}`} />
                      <span>{item.label}</span>
                    </button>
                  ))}
                </div>
              ))}
              <button className="sidebar-link" onClick={() => void onLogout()}>
                <i className="bi bi-box-arrow-right" />
                <span>Đăng xuất</span>
              </button>
            </div>
          </div>
        </aside>

        <section className="admin-main">
          <section className="hero-card">
            <div className="admin-header">
              <div>
                <div className="eyebrow">Xin chào, {staff?.name ?? "Admin"}</div>
                <h1>{title}</h1>
                <p className="muted-line">{description}</p>
                <p className="muted-line">
                  <i className="bi bi-building" /> {staff?.branchName ?? "Chưa có chi nhánh"} {" · "}
                  <i className="bi bi-shield-check" /> {staff?.roleName ?? "Quản trị"}
                </p>
              </div>
              <div className="header-actions">
                <span className="status-pill info">{new Date().toLocaleString("vi-VN")}</span>
                {onRefresh ? <button className="ghost" onClick={() => void onRefresh()}>Làm mới</button> : null}
              </div>
            </div>
          </section>

          {message ? <div className="success-box">{message}</div> : null}
          {error ? <div className="error-box">{error}</div> : null}

          {children}
        </section>
      </div>
    </main>
  );
}
