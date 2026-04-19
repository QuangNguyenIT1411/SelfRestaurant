export type ApiError = {
  success: false;
  code: string;
  message: string;
  details?: unknown;
};

export type StaffSessionUserDto = {
  employeeId: number;
  username: string;
  name: string;
  phone?: string | null;
  email?: string | null;
  roleId: number;
  roleCode: string;
  roleName: string;
  branchId: number;
  branchName: string;
};

export type StaffSessionDto = {
  authenticated: boolean;
  staff?: StaffSessionUserDto | null;
  loginPath?: string | null;
};

export type CashierTableDto = {
  tableId: number;
  number: string;
  seats: number;
  status: string;
  orderId?: number | null;
};

export type CashierOrderItemCardDto = {
  dishName: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
  image: string;
};

export type CashierOrderCardDto = {
  orderId: number;
  orderCode: string;
  statusCode: string;
  statusName: string;
  customerId?: number | null;
  customerName: string;
  customerCreditPoints: number;
  subtotal: number;
  itemCount: number;
  items: CashierOrderItemCardDto[];
};

export type CashierBillHistoryItemDto = {
  billId: number;
  billCode: string;
  billTime: string;
  orderCode: string;
  tableName: string;
  subtotal: number;
  discount: number;
  pointsDiscount: number;
  pointsUsed?: number | null;
  totalAmount: number;
  paymentMethod: string;
  paymentAmount?: number | null;
  changeAmount?: number | null;
  customerName: string;
};

export type CashierAccountDto = {
  employeeId: number;
  name: string;
  username: string;
  email: string;
  phone: string;
  branchName: string;
  roleName: string;
};

export type CashierDashboardDto = {
  staff: StaffSessionUserDto;
  tables: CashierTableDto[];
  orders: CashierOrderCardDto[];
  todayOrders: number;
  todayRevenue: number;
  account: CashierAccountDto;
};

export type CashierHistoryDto = {
  staff: StaffSessionUserDto;
  bills: CashierBillHistoryItemDto[];
  account: CashierAccountDto;
};

export type CashierReportScreenDto = {
  staff: StaffSessionUserDto;
  date: string;
  billCount: number;
  totalRevenue: number;
  bills: CashierBillHistoryItemDto[];
  account: CashierAccountDto;
};

export type CashierCheckoutResultDto = {
  billCode: string;
  totalAmount: number;
  changeAmount: number;
  pointsUsed: number;
  pointsEarned: number;
  customerPoints: number;
  customerName?: string | null;
  pointsBefore: number;
  message: string;
};
