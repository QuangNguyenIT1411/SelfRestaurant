import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { cashierApi } from "../lib/api";
import type { CashierCheckoutResultDto, CashierDashboardDto } from "../lib/types";

type Props = {
  onLogout: () => Promise<void>;
};

type CheckoutResultView = CashierCheckoutResultDto & {
  orderCode: string;
  paymentMethod: string;
  paymentAmount: number;
};

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

function paymentMethodLabel(value: string) {
  return value === "CARD" ? "Thẻ ngân hàng" : value === "CASH" ? "Tiền mặt" : value;
}

export function DashboardPage({ onLogout }: Props) {
  const [dashboard, setDashboard] = useState<CashierDashboardDto | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [tableSearch, setTableSearch] = useState("");
  const [activeTableId, setActiveTableId] = useState<number | null>(null);
  const [discountAmount, setDiscountAmount] = useState("0");
  const [discountPercent, setDiscountPercent] = useState("0");
  const [pointsUsedInput, setPointsUsedInput] = useState("0");
  const [paymentMethod, setPaymentMethod] = useState<"CASH" | "CARD">("CASH");
  const [paymentAmount, setPaymentAmount] = useState("");
  const [checkoutResult, setCheckoutResult] = useState<CheckoutResultView | null>(null);

  async function loadDashboard() {
    setLoading(true);
    setError(null);
    try {
      setDashboard(await cashierApi.getDashboard());
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể tải dữ liệu thu ngân.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadDashboard();
  }, []);

  useEffect(() => {
    if (!dashboard) return;
    if (activeTableId != null && dashboard.tables.some((table) => table.tableId === activeTableId)) {
      return;
    }
    setActiveTableId(null);
  }, [activeTableId, dashboard]);

  const visibleTables = useMemo(() => {
    const keyword = tableSearch.trim().toLowerCase();
    return dashboard?.tables.filter((table) => keyword.length === 0 || table.number.toLowerCase().includes(keyword)) ?? [];
  }, [dashboard, tableSearch]);

  const selectedTable = useMemo(() => {
    if (!dashboard || activeTableId == null) return null;
    return dashboard.tables.find((table) => table.tableId === activeTableId) ?? null;
  }, [activeTableId, dashboard]);

  const activeOrder = useMemo(() => {
    if (!dashboard || !selectedTable?.orderId) return null;
    return dashboard.orders.find((order) => order.orderId === selectedTable.orderId) ?? null;
  }, [dashboard, selectedTable]);

  const subtotal = activeOrder?.subtotal ?? 0;
  const pointsAvailable = activeOrder?.customerCreditPoints ?? 0;

  const checkoutPreview = useMemo(() => {
    const rawDiscount = Number(discountAmount || "0");
    const safeDiscount = Number.isFinite(rawDiscount) ? clamp(rawDiscount, 0, subtotal) : 0;
    const baseTotal = Math.max(0, subtotal - safeDiscount);
    const maxPointsAllowed = Math.floor(Math.min(pointsAvailable, Math.floor(baseTotal * 0.1)) / 1000) * 1000;
    const rawPoints = Number(pointsUsedInput || "0");
    const safePoints = Number.isFinite(rawPoints) ? Math.floor(clamp(rawPoints, 0, maxPointsAllowed) / 1000) * 1000 : 0;
    const total = Math.max(0, subtotal - safeDiscount - safePoints);
    const rawPayment = Number(paymentAmount || "0");
    const safePayment = Number.isFinite(rawPayment) ? Math.max(0, rawPayment) : 0;
    const effectivePayment = paymentMethod === "CARD" ? total : safePayment;
    const changeAmount = Math.max(0, effectivePayment - total);

    return {
      discount: safeDiscount,
      maxPointsAllowed,
      pointsUsed: safePoints,
      total,
      paymentAmount: effectivePayment,
      changeAmount,
    };
  }, [discountAmount, paymentAmount, paymentMethod, pointsAvailable, pointsUsedInput, subtotal]);

  useEffect(() => {
    if (!activeOrder) {
      setDiscountAmount("0");
      setDiscountPercent("0");
      setPointsUsedInput("0");
      setPaymentMethod("CASH");
      setPaymentAmount("");
      return;
    }

    setDiscountAmount("0");
    setDiscountPercent("0");
    setPointsUsedInput("0");
    setPaymentMethod("CASH");
    setPaymentAmount("");
  }, [activeOrder?.orderId]);

  useEffect(() => {
    if (paymentMethod === "CARD") {
      setPaymentAmount(String(checkoutPreview.total));
    }
  }, [checkoutPreview.total, paymentMethod]);

  function handleDiscountAmountChange(value: string) {
    setDiscountAmount(value);
    const numericValue = clamp(Number(value || "0") || 0, 0, subtotal);
    const percent = subtotal > 0 ? (numericValue / subtotal) * 100 : 0;
    setDiscountPercent(percent.toFixed(2).replace(/\.00$/, ""));
  }

  function handleDiscountPercentChange(value: string) {
    const normalizedPercent = clamp(Number(value || "0") || 0, 0, 100);
    setDiscountPercent(value);
    setDiscountAmount(String(Math.floor(subtotal * (normalizedPercent / 100))));
  }

  function useSmartPoints() {
    setPointsUsedInput(String(checkoutPreview.maxPointsAllowed));
  }

  function clearPoints() {
    setPointsUsedInput("0");
  }

  function setQuickAmount(amount: number) {
    setPaymentAmount(String(amount));
  }

  function setExactAmount() {
    setPaymentAmount(String(checkoutPreview.total));
  }

  function clearAmount() {
    setPaymentAmount("");
  }

  async function processCheckout() {
    if (!activeOrder) return;
    setError(null);
    setMessage(null);

    if (paymentMethod === "CASH" && checkoutPreview.paymentAmount < checkoutPreview.total) {
      window.alert("Không đủ tiền thanh toán hóa đơn.");
      return;
    }

    try {
      const result = await cashierApi.checkout(activeOrder.orderId, {
        discount: checkoutPreview.discount,
        pointsUsed: checkoutPreview.pointsUsed,
        paymentMethod,
        paymentAmount: checkoutPreview.paymentAmount,
      });

      setCheckoutResult({
        ...result,
        orderCode: activeOrder.orderCode,
        paymentMethod,
        paymentAmount: checkoutPreview.paymentAmount,
      });
      setMessage(result.message);
      await loadDashboard();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không thể thanh toán hóa đơn.");
    }
  }

  if (loading) return <div className="screen-message">Đang tải quầy thu ngân...</div>;
  if (error && !dashboard) return <div className="screen-message error-box">{error}</div>;
  if (!dashboard) return null;

  const occupiedCount = dashboard.tables.filter((table) => table.status === "OCCUPIED").length;
  const selectedTableTitle = selectedTable ? selectedTable.number : "Chưa chọn bàn";
  const canCheckout = !!activeOrder;

  return (
    <main className="cashier-shell">
      <section className="hero-card cashier-hero">
        <header className="cashier-header">
          <div>
            <h1>Quầy Thu Ngân</h1>
            <p className="muted">{dashboard.staff.branchName}</p>
            <p className="muted">Nhân viên thu ngân: {dashboard.staff.name} ({dashboard.staff.roleName})</p>
          </div>
          <div className="header-actions">
            <Link className="cashier-link-button" to="/Staff/Cashier/Report">
              <i className="bi bi-printer me-1" />
              Báo cáo theo ngày
            </Link>
            <Link className="cashier-link-button" to="/Staff/Cashier/History">
              <i className="bi bi-clock-history me-1" />
              Lịch sử & Tài khoản
            </Link>
            <button className="ghost" onClick={() => void onLogout()}>
              <i className="bi bi-box-arrow-right me-1" />
              Đăng xuất
            </button>
          </div>
        </header>

        <section className="stats-grid">
          <article>
            <strong>{dashboard.todayOrders}</strong>
            <span>Đơn hôm nay</span>
          </article>
          <article>
            <strong>{dashboard.todayRevenue.toLocaleString("vi-VN")} đ</strong>
            <span>Doanh thu</span>
          </article>
        </section>
      </section>

      {message ? <div className="success-box">{message}</div> : null}
      {error ? <div className="error-box">{error}</div> : null}

      <section className="split-grid cash-grid">
        <div className="panel cashier-panel-card">
          <div className="cashier-panel-header">
            <h2>
              <i className="bi bi-table me-2" />
              Chọn bàn
            </h2>
          </div>
          <div className="cashier-panel-body">
            <div className="table-search-group">
              <i className="bi bi-search" />
              <input
                type="text"
                value={tableSearch}
                onChange={(event) => setTableSearch(event.target.value)}
                placeholder="Nhập số bàn cần tìm..."
              />
            </div>
            <div className="cashier-status-summary">
              <span className="soft-badge success">{dashboard.tables.length - occupiedCount} bàn trống</span>
              <span className="soft-badge warning">{occupiedCount} bàn đang sử dụng</span>
            </div>

            <div className="table-grid">
              {visibleTables.length > 0 ? (
                visibleTables.map((table) => (
                  <article
                    key={table.tableId}
                    className={`table-card ${table.status.toLowerCase()} ${selectedTable?.tableId === table.tableId ? "selected" : ""}`}
                    onClick={() => setActiveTableId(table.tableId)}
                  >
                    <div className="table-number">{table.number}</div>
                    <div className={`table-status ${table.status === "AVAILABLE" ? "available" : "occupied"}`}>
                      {table.status === "AVAILABLE" ? "Trống" : "Có khách"}
                    </div>
                    <small className="muted">{table.seats} ghế</small>
                  </article>
                ))
              ) : (
                <div className="cashier-empty-state">
                  <i className="bi bi-search" />
                  <p>Không tìm thấy bàn</p>
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="panel cashier-panel-card">
          <div className="cashier-panel-header">
            <h2>
              <i className="bi bi-receipt me-2" />
              Chi tiết đơn hàng
            </h2>
            <span className="soft-badge info">{selectedTableTitle}</span>
          </div>
          <div className="cashier-panel-body cashier-panel-body-scroll">
            {!selectedTable ? (
              <div className="cashier-empty-state">
                <i className="bi bi-cart-x" />
                <p>Chọn bàn để xem đơn hàng</p>
              </div>
            ) : !activeOrder ? (
              <div className="cashier-empty-state">
                <i className="bi bi-info-circle" />
                <p>Bàn này chưa có đơn hàng</p>
              </div>
            ) : (
              <>
                <div className="inline-filter-card cashier-order-summary-card">
                  <div>
                    <strong>{activeOrder.orderCode}</strong>
                    <div className="muted">{activeOrder.customerName || "Khách lẻ"}</div>
                  </div>
                  <span className="soft-badge info">{activeOrder.statusName}</span>
                </div>

                <div className="detail-list">
                  {activeOrder.items.map((item, index) => (
                    <article key={`${activeOrder.orderId}-${index}`} className="detail-item-card">
                      <div className="d-flex" style={{ gap: "1rem" }}>
                        {item.image ? (
                          <img
                            src={item.image}
                            alt={item.dishName}
                            style={{ width: "60px", height: "60px", objectFit: "cover", borderRadius: "8px", border: "1px solid #e5e7eb" }}
                          />
                        ) : null}
                        <div>
                          <strong>{item.dishName}</strong>
                          <p>Số lượng: {item.quantity} x {item.unitPrice.toLocaleString("vi-VN")} đ</p>
                        </div>
                      </div>
                      <strong>{item.lineTotal.toLocaleString("vi-VN")} đ</strong>
                    </article>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>

        <div className="panel cashier-panel-card">
          <div className="cashier-panel-header">
            <h2>
              <i className="bi bi-credit-card me-2" />
              Thanh toán
            </h2>
          </div>
          <div className="cashier-panel-body">
            <div className="total-section">
              <div className="total-row">
                <span>Tạm tính:</span>
                <strong>{subtotal.toLocaleString("vi-VN")} đ</strong>
              </div>
              <div className="total-row">
                <span>Giảm giá:</span>
                <div className="d-flex align-items-center" style={{ gap: ".5rem" }}>
                  <input
                    type="number"
                    min="0"
                    value={discountAmount}
                    onChange={(event) => handleDiscountAmountChange(event.target.value)}
                    style={{ width: "120px" }}
                  />
                  <span className="muted">đ</span>
                </div>
              </div>
              <div className="total-row">
                <span>Giảm theo %:</span>
                <div className="d-flex align-items-center" style={{ gap: ".5rem" }}>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    value={discountPercent}
                    onChange={(event) => handleDiscountPercentChange(event.target.value)}
                    style={{ width: "120px" }}
                  />
                  <span className="muted">%</span>
                </div>
              </div>
              {checkoutPreview.pointsUsed > 0 ? (
                <div className="total-row">
                  <span>Giảm bằng điểm:</span>
                  <strong>-{checkoutPreview.pointsUsed.toLocaleString("vi-VN")} đ</strong>
                </div>
              ) : null}
              <div className="total-row grand-total">
                <span>TỔNG CỘNG:</span>
                <span>{checkoutPreview.total.toLocaleString("vi-VN")} đ</span>
              </div>
            </div>

            {activeOrder?.customerId ? (
              <div className="credit-points-section">
                <div className="credit-balance">
                  <span>Số dư hiện tại:</span>
                  <span className="credit-amount">{pointsAvailable.toLocaleString("vi-VN")} điểm</span>
                </div>
                <label>
                  Sử dụng điểm (1 điểm = 1 đ):
                  <input
                    className="points-input"
                    type="number"
                    min="0"
                    max={checkoutPreview.maxPointsAllowed}
                    value={pointsUsedInput}
                    onChange={(event) => setPointsUsedInput(event.target.value)}
                  />
                </label>
                <div className="checkout-quick-grid">
                  <button className="cashier-button-primary checkout-quick-button" onClick={useSmartPoints}>
                    Thanh toán thông minh
                  </button>
                  <button className="cashier-button-outline checkout-quick-button" onClick={clearPoints}>
                    Xóa điểm
                  </button>
                </div>
                {checkoutPreview.maxPointsAllowed > 0 ? (
                  <div className="soft-badge warning">
                    Trừ tối đa {checkoutPreview.maxPointsAllowed.toLocaleString("vi-VN")} điểm cho hóa đơn này
                  </div>
                ) : null}
              </div>
            ) : null}

            <div className="stack">
              <label>Phương thức thanh toán:</label>
              <div className="payment-method-grid">
                <button
                  className={`payment-method-tile ${paymentMethod === "CASH" ? "active" : ""}`}
                  onClick={() => setPaymentMethod("CASH")}
                >
                  <i className="bi bi-cash-stack" />
                  <strong>Tiền mặt</strong>
                </button>
                <button
                  className={`payment-method-tile ${paymentMethod === "CARD" ? "active" : ""}`}
                  onClick={() => setPaymentMethod("CARD")}
                >
                  <i className="bi bi-credit-card" />
                  <strong>Thẻ ngân hàng</strong>
                </button>
              </div>
            </div>

            {paymentMethod === "CASH" ? (
              <div className="stack">
                <label>
                  Tiền khách đưa:
                  <input
                    className="payment-input"
                    type="number"
                    min="0"
                    value={paymentAmount}
                    onChange={(event) => setPaymentAmount(event.target.value)}
                    placeholder="0"
                  />
                </label>
                <div className="checkout-quick-grid">
                  <button className="cashier-button-outline checkout-quick-button" onClick={() => setQuickAmount(50000)}>50k</button>
                  <button className="cashier-button-outline checkout-quick-button" onClick={() => setQuickAmount(100000)}>100k</button>
                  <button className="cashier-button-outline checkout-quick-button" onClick={() => setQuickAmount(200000)}>200k</button>
                  <button className="cashier-button-outline checkout-quick-button" onClick={() => setQuickAmount(500000)}>500k</button>
                  <button className="cashier-button-outline checkout-quick-button" onClick={setExactAmount}>Vừa đủ</button>
                  <button className="cashier-button-outline checkout-quick-button" onClick={clearAmount}>Xóa</button>
                </div>
                {checkoutPreview.changeAmount > 0 ? (
                  <div className="success-box">
                    <strong>Tiền thối lại:</strong> {checkoutPreview.changeAmount.toLocaleString("vi-VN")} đ
                  </div>
                ) : null}
              </div>
            ) : null}

            <button className="cashier-button-primary wide" disabled={!canCheckout} onClick={() => void processCheckout()}>
              <i className="bi bi-check-circle me-2" />
              Xác nhận thanh toán
            </button>
          </div>
        </div>
      </section>

      {checkoutResult ? (
        <div className="modal-backdrop">
          <div className="modal-card cashier-modal-card">
            <div className="cashier-panel-header">
              <h2>
                <i className="bi bi-check-circle-fill me-2" />
                Thanh toán thành công
              </h2>
              <button className="ghost" onClick={() => setCheckoutResult(null)}>
                Đóng
              </button>
            </div>
            <div className="cashier-panel-body">
              <div className="cashier-empty-state" style={{ minHeight: "unset", padding: "1rem" }}>
                <i className="bi bi-check-circle" style={{ color: "#198754" }} />
                <p>Đã thanh toán thành công!</p>
              </div>

              <div className="bill-meta-grid">
                <div className="bill-meta-card">
                  <span>Mã đơn hàng</span>
                  <strong>{checkoutResult.orderCode}</strong>
                </div>
                <div className="bill-meta-card">
                  <span>Mã hóa đơn</span>
                  <strong>{checkoutResult.billCode}</strong>
                </div>
                <div className="bill-meta-card">
                  <span>Phương thức</span>
                  <strong>{paymentMethodLabel(checkoutResult.paymentMethod)}</strong>
                </div>
              </div>

              <div className="bill-breakdown">
                <div>
                  <span>Thành tiền</span>
                  <strong>{checkoutResult.totalAmount.toLocaleString("vi-VN")} đ</strong>
                </div>
                <div>
                  <span>Tiền khách đưa</span>
                  <strong>{checkoutResult.paymentAmount.toLocaleString("vi-VN")} đ</strong>
                </div>
                <div>
                  <span>Tiền thừa</span>
                  <strong>{checkoutResult.changeAmount.toLocaleString("vi-VN")} đ</strong>
                </div>
              </div>

              <div className="cashier-modal-footer">
                <button className="cashier-button-primary" onClick={() => window.print()}>
                  <i className="bi bi-printer me-2" />
                  In hóa đơn
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </main>
  );
}
