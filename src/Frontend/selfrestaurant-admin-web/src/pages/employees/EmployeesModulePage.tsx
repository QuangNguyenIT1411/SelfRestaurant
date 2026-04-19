import { useEffect, useState } from "react";
import { useLocation, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { AdminLayout } from "../../components/AdminLayout";
import { adminApi } from "../../lib/api";
import type { AdminEmployeeDto, AdminEmployeeHistoryResponse, AdminEmployeesScreenDto, StaffSessionUserDto } from "../../lib/types";

type Props = {
  mode: "index" | "create" | "edit" | "history";
  onLogout: () => Promise<void>;
};

const emptyEmployeeForm = {
  name: "",
  username: "",
  password: "",
  phone: "",
  email: "",
  salary: "",
  shift: "",
  branchId: "",
  roleId: "",
  isActive: true,
};

function formatDateTime(value?: string | null) {
  if (!value) return "-";
  return new Date(value).toLocaleString("vi-VN");
}

export function EmployeesModulePage({ mode, onLogout }: Props) {
  const location = useLocation();
  const navigate = useNavigate();
  const { employeeId } = useParams();
  const [searchParams] = useSearchParams();
  const [staff, setStaff] = useState<StaffSessionUserDto | null>(null);
  const [screen, setScreen] = useState<AdminEmployeesScreenDto | null>(null);
  const [history, setHistory] = useState<AdminEmployeeHistoryResponse | null>(null);
  const [form, setForm] = useState(emptyEmployeeForm);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const search = searchParams.get("search") ?? "";
  const branchId = searchParams.get("branchId") ?? "ALL";
  const roleId = searchParams.get("roleId") ?? "ALL";
  const page = Math.max(1, Number.parseInt(searchParams.get("page") ?? "1", 10) || 1);
  const employeeIdValue = employeeId ? Number.parseInt(employeeId, 10) : 0;

  useEffect(() => {
    const flash = (location.state as { message?: string } | null)?.message;
    if (flash) {
      setMessage(flash);
      navigate(location.pathname + location.search, { replace: true, state: null });
    }
  }, [location.pathname, location.search, location.state, navigate]);

  async function loadPage() {
    setLoading(true);
    setError(null);
    try {
      const session = await adminApi.getSession();
      setStaff(session.staff ?? null);

      if (mode === "index") {
        setScreen(await adminApi.getEmployees(
          search,
          branchId !== "ALL" ? Number(branchId) : undefined,
          roleId !== "ALL" ? Number(roleId) : undefined,
          page,
          10,
        ));
      } else if (mode === "create") {
        const next = await adminApi.getEmployees("", undefined, undefined, 1, 10);
        setScreen(next);
        setForm((current) => ({
          ...current,
          branchId: current.branchId || String(next.branches[0]?.branchId ?? ""),
          roleId: current.roleId || String(next.roles[0]?.roleId ?? ""),
        }));
      } else if (mode === "edit") {
        if (!employeeIdValue) {
          navigate("/Admin/Employees/Index", { replace: true });
          return;
        }
        const [next, employee] = await Promise.all([
          adminApi.getEmployees("", undefined, undefined, 1, 10),
          adminApi.getEmployeeById(employeeIdValue),
        ]);
        setScreen(next);
        setForm({
          name: employee.name,
          username: employee.username,
          password: "",
          phone: employee.phone ?? "",
          email: employee.email ?? "",
          salary: employee.salary != null ? String(employee.salary) : "",
          shift: employee.shift ?? "",
          branchId: String(employee.branchId),
          roleId: String(employee.roleId),
          isActive: employee.isActive,
        });
      } else {
        if (!employeeIdValue) {
          navigate("/Admin/Employees/Index", { replace: true });
          return;
        }
        setHistory(await adminApi.getEmployeeHistory(employeeIdValue));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể tải dữ liệu nhân viên.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadPage();
  }, [mode, search, branchId, roleId, page, employeeIdValue]);

  function buildIndexUrl(nextPage = page, nextSearch = search, nextBranchId = branchId, nextRoleId = roleId) {
    const params = new URLSearchParams();
    if (nextSearch.trim()) params.set("search", nextSearch.trim());
    if (nextBranchId !== "ALL") params.set("branchId", nextBranchId);
    if (nextRoleId !== "ALL") params.set("roleId", nextRoleId);
    if (nextPage > 1) params.set("page", String(nextPage));
    return `/Admin/Employees/Index${params.toString() ? `?${params.toString()}` : ""}`;
  }

  async function handleDeactivate(employee: AdminEmployeeDto) {
    if (!window.confirm("Bạn có chắc muốn khóa nhân viên này?")) return;
    try {
      const response = await adminApi.deactivateEmployee(employee.employeeId);
      setMessage(response.message);
      await loadPage();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể khóa nhân viên.");
    }
  }

  async function handleCreate() {
    if (!form.name.trim() || !form.username.trim() || !form.password.trim() || !form.branchId || !form.roleId) {
      setError("Vui lòng nhập đầy đủ họ tên, tên đăng nhập, mật khẩu, chi nhánh và vai trò.");
      return;
    }

    try {
      const response = await adminApi.createEmployee({
        name: form.name.trim(),
        username: form.username.trim(),
        password: form.password.trim(),
        phone: form.phone.trim() || null,
        email: form.email.trim() || null,
        salary: form.salary ? Number(form.salary) : null,
        shift: form.shift.trim() || null,
        isActive: form.isActive,
        branchId: Number(form.branchId),
        roleId: Number(form.roleId),
      });
      navigate("/Admin/Employees/Index", { replace: true, state: { message: response.message } });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể thêm nhân viên.");
    }
  }

  async function handleEdit() {
    if (!employeeIdValue) return;
    if (!form.name.trim() || !form.username.trim() || !form.branchId || !form.roleId) {
      setError("Vui lòng nhập đầy đủ họ tên, tên đăng nhập, chi nhánh và vai trò.");
      return;
    }

    try {
      const response = await adminApi.updateEmployee(employeeIdValue, {
        name: form.name.trim(),
        username: form.username.trim(),
        password: form.password.trim() || null,
        phone: form.phone.trim() || null,
        email: form.email.trim() || null,
        salary: form.salary ? Number(form.salary) : null,
        shift: form.shift.trim() || null,
        isActive: form.isActive,
        branchId: Number(form.branchId),
        roleId: Number(form.roleId),
      });
      navigate("/Admin/Employees/Index", { replace: true, state: { message: response.message } });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể cập nhật nhân viên.");
    }
  }

  const title = mode === "create"
    ? "Thêm nhân viên"
    : mode === "edit"
      ? "Cập nhật nhân viên"
      : mode === "history"
        ? "Lịch sử nhân viên"
        : "Quản lý nhân viên";
  const description = mode === "create"
    ? "Tạo mới tài khoản nhân viên."
    : mode === "edit"
      ? "Cập nhật thông tin nhân viên."
      : mode === "history"
        ? "Xem lịch sử hoạt động của nhân viên."
        : "Quản lý nhân sự, vai trò và chi nhánh.";

  return (
    <AdminLayout title={title} description={description} staff={staff} onLogout={onLogout} onRefresh={loadPage} message={message} error={error}>
      {loading ? <div className="screen-message">Đang tải dữ liệu nhân viên...</div> : null}

      {!loading && mode === "index" && screen ? (
        <section className="panel">
          <div className="toolbar-card">
            <div>
              <strong>Danh sách nhân viên</strong>
              <div className="muted">Tìm kiếm, lọc, chỉnh sửa, xem lịch sử và khóa tài khoản.</div>
            </div>
            <button className="ghost" onClick={() => navigate("/Admin/Employees/Create")}>Thêm nhân viên</button>
          </div>

          <div className="inline-filter-card admin-filter-card">
            <div>
              <strong>Bộ lọc tìm kiếm</strong>
              <div className="muted">Tìm theo tên, tên đăng nhập, số điện thoại, email, chi nhánh hoặc vai trò.</div>
            </div>
            <div className="admin-filter-form">
              <label className="admin-filter-field admin-filter-field-wide">
                <span>Từ khóa</span>
                <input value={search} onChange={(e) => navigate(buildIndexUrl(1, e.target.value, branchId, roleId), { replace: true })} placeholder="Tên, tài khoản, số điện thoại..." />
              </label>
              <label className="admin-filter-field">
                <span>Chi nhánh</span>
                <select value={branchId} onChange={(e) => navigate(buildIndexUrl(1, search, e.target.value, roleId))}>
                  <option value="ALL">Tất cả chi nhánh</option>
                  {screen.branches.map((branch) => (
                    <option key={branch.branchId} value={branch.branchId}>{branch.name}</option>
                  ))}
                </select>
              </label>
              <label className="admin-filter-field">
                <span>Vai trò</span>
                <select value={roleId} onChange={(e) => navigate(buildIndexUrl(1, search, branchId, e.target.value))}>
                  <option value="ALL">Tất cả vai trò</option>
                  {screen.roles.map((role) => (
                    <option key={role.roleId} value={role.roleId}>{role.roleName}</option>
                  ))}
                </select>
              </label>
              <div className="admin-filter-actions">
                <button className="ghost" onClick={() => navigate("/Admin/Employees/Index")}>Xóa lọc</button>
              </div>
            </div>
          </div>

          <table className="data-table">
            <thead>
              <tr>
                <th>Nhân viên</th>
                <th>Tài khoản</th>
                <th>Vai trò</th>
                <th>Chi nhánh</th>
                <th>Liên hệ</th>
                <th>Ca làm</th>
                <th>Lương</th>
                <th>Trạng thái</th>
                <th>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {screen.employees.items.length === 0 ? (
                <tr>
                  <td colSpan={9}>
                    <div className="empty-report compact-empty">Không tìm thấy nhân viên phù hợp.</div>
                  </td>
                </tr>
              ) : screen.employees.items.map((employee) => (
                <tr key={employee.employeeId}>
                  <td><strong>{employee.name}</strong></td>
                  <td>{employee.username}</td>
                  <td>{employee.roleName}</td>
                  <td>{employee.branchName}</td>
                  <td>
                    <div className="contact-stack">
                      <span>{employee.phone || "-"}</span>
                      <span className="muted-caption">{employee.email || "-"}</span>
                    </div>
                  </td>
                  <td>{employee.shift || "-"}</td>
                  <td>{employee.salary != null ? `${employee.salary.toLocaleString("vi-VN")} đ` : "-"}</td>
                  <td>{employee.isActive ? <span className="status-pill success">Hoạt động</span> : <span className="status-pill danger">Khóa</span>}</td>
                  <td>
                    <div className="button-row wrap">
                      <button className="ghost" onClick={() => navigate(`/Admin/Employees/Edit/${employee.employeeId}`)}>Sửa</button>
                      <button className="ghost" onClick={() => navigate(`/Admin/Employees/History/${employee.employeeId}`)}>Lịch sử</button>
                      <button className="danger" onClick={() => void handleDeactivate(employee)}>Khóa</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {screen.employees.totalPages > 1 ? (
            <div className="button-row wrap admin-pagination">
              {Array.from({ length: screen.employees.totalPages }, (_, index) => index + 1).map((pageNumber) => (
                <button key={`employee-page-${pageNumber}`} className={pageNumber === screen.employees.page ? "active-toggle" : "ghost"} onClick={() => navigate(buildIndexUrl(pageNumber))}>
                  {pageNumber}
                </button>
              ))}
            </div>
          ) : null}
        </section>
      ) : null}

      {!loading && (mode === "create" || mode === "edit") && screen ? (
        <section className="panel">
          <article className={`entry-form-card ${mode === "edit" ? "edit-form-card" : ""}`}>
            <div className="entry-form-header">
              <div>
                <strong>{mode === "create" ? "Thêm nhân viên mới" : "Cập nhật nhân viên"}</strong>
                <div className="muted">{mode === "create" ? "Nhập đầy đủ thông tin tài khoản, chi nhánh và vai trò." : "Để trống mật khẩu nếu không thay đổi."}</div>
              </div>
            </div>
            <div className="entry-form-grid">
              <label>Họ tên
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
              </label>
              <label>Tên đăng nhập
                <input value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} />
              </label>
              <label>{mode === "create" ? "Mật khẩu" : "Mật khẩu mới"}
                <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder={mode === "edit" ? "Để trống nếu không đổi" : ""} />
              </label>
              <label>Số điện thoại
                <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
              </label>
              <label>Email
                <input value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
              </label>
              <label>Lương
                <input type="number" value={form.salary} onChange={(e) => setForm({ ...form, salary: e.target.value })} />
              </label>
              <label>Ca làm
                <input value={form.shift} onChange={(e) => setForm({ ...form, shift: e.target.value })} />
              </label>
              <label>Chi nhánh
                <select value={form.branchId} onChange={(e) => setForm({ ...form, branchId: e.target.value })}>
                  {screen.branches.map((branch) => (
                    <option key={branch.branchId} value={branch.branchId}>{branch.name}</option>
                  ))}
                </select>
              </label>
              <label>Vai trò
                <select value={form.roleId} onChange={(e) => setForm({ ...form, roleId: e.target.value })}>
                  {screen.roles.map((role) => (
                    <option key={role.roleId} value={role.roleId}>{role.roleName}</option>
                  ))}
                </select>
              </label>
              <label className="admin-checkbox-field">
                <span>Trạng thái</span>
                <div className="checkbox-inline">
                  <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} />
                  <span>Hoạt động</span>
                </div>
              </label>
            </div>
            <div className="entry-form-actions">
              <button className="ghost" onClick={() => navigate("/Admin/Employees/Index")}>Hủy</button>
              <button onClick={() => void (mode === "create" ? handleCreate() : handleEdit())}>{mode === "create" ? "Lưu nhân viên" : "Lưu thay đổi"}</button>
            </div>
          </article>
        </section>
      ) : null}

      {!loading && mode === "history" ? (
        <section className="panel">
          <article className="panel">
            <div className="panel-head">
              <div>
                <h2>Lịch sử nhân viên</h2>
                <p className="muted">Theo dõi lịch sử hoạt động của nhân viên trong 90 ngày gần nhất.</p>
              </div>
              <button className="ghost" onClick={() => navigate("/Admin/Employees/Index")}>Quay lại</button>
            </div>
            {!history ? (
              <div className="empty-report history-empty-card">
                <strong>Chưa có lịch sử nhân viên.</strong>
                <div>Không thể tải dữ liệu lịch sử cho nhân viên này.</div>
              </div>
            ) : (
              <div className="stack">
                <div className="inline-filter-card">
                  <div>
                    <strong>{history.employee.employeeName}</strong>
                    <div className="muted">{history.employee.roleName} | {history.employee.branchName}</div>
                  </div>
                </div>

                <div className="history-block">
                  <div className="history-block-title">Lịch sử bếp</div>
                  {history.chefHistory.length === 0 ? (
                    <div className="empty-report compact-empty">Chưa có lịch sử bếp.</div>
                  ) : (
                    <table className="data-table compact-table">
                      <thead>
                        <tr>
                          <th>Mã đơn</th>
                          <th>Thời gian tạo</th>
                          <th>Hoàn tất</th>
                          <th>Bàn</th>
                          <th>Trạng thái</th>
                          <th>Món</th>
                        </tr>
                      </thead>
                      <tbody>
                        {history.chefHistory.map((item) => (
                          <tr key={`chef-${item.orderId}`}>
                            <td>{item.orderCode || `ORDER-${item.orderId}`}</td>
                            <td>{formatDateTime(item.orderTime)}</td>
                            <td>{formatDateTime(item.completedTime)}</td>
                            <td>{item.tableName || "-"}</td>
                            <td>{item.statusName}</td>
                            <td>{item.dishesSummary || "-"}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>

                <div className="history-block">
                  <div className="history-block-title">Lịch sử thu ngân</div>
                  {history.cashierHistory.length === 0 ? (
                    <div className="empty-report compact-empty">Chưa có lịch sử thu ngân.</div>
                  ) : (
                    <table className="data-table compact-table">
                      <thead>
                        <tr>
                          <th>Mã hóa đơn</th>
                          <th>Thời gian</th>
                          <th>Mã đơn</th>
                          <th>Bàn</th>
                          <th>Khách hàng</th>
                          <th>Tổng tiền</th>
                        </tr>
                      </thead>
                      <tbody>
                        {history.cashierHistory.map((item) => (
                          <tr key={`cash-${item.billId}`}>
                            <td>{item.billCode}</td>
                            <td>{formatDateTime(item.billTime)}</td>
                            <td>{item.orderCode || "-"}</td>
                            <td>{item.tableName || "-"}</td>
                            <td>{item.customerName || "-"}</td>
                            <td>{item.totalAmount.toLocaleString("vi-VN")} đ</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>
            )}
          </article>
        </section>
      ) : null}
    </AdminLayout>
  );
}
