// Shapes shared by all layers. These are what the API returns as JSON.

export const ROLES = ["customer", "restaurant_owner", "courier", "admin"] as const;
export type Role = (typeof ROLES)[number]; // "customer" | "restaurant_owner" | ...

export type User = {
  id: number;
  email: string;
  name: string;
  role: Role;
  createdAt: Date;
};

// Who is making the request, as read from their token.
export type AuthUser = {
  id: number;
  role: Role;
};

export type Restaurant = {
  id: number;
  name: string;
  isOpen: boolean;
};

export type MenuItem = {
  id: number;
  categoryId: number;
  name: string;
  description: string;
  priceCents: number; // money as whole cents: 1050 means 10.50
  isAvailable: boolean;
};

export type MenuCategory = {
  id: number;
  name: string;
  items: MenuItem[];
};

export type Menu = {
  restaurantId: number;
  categories: MenuCategory[];
};

export const ORDER_STATUSES = [
  "pending",
  "accepted",
  "preparing",
  "ready",
  "picked_up",
  "delivered",
  "cancelled",
] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];

export type Order = {
  id: number;
  customerId: number;
  restaurantId: number;
  restaurantName: string;
  status: OrderStatus;
  deliveryAddress: string;
  totalCents: number;
  createdAt: Date;
  updatedAt: Date;
};

// One line of an order. name and unitPriceCents are copies made when the order
// was placed, so later menu changes don't affect it.
export type OrderItem = {
  menuItemId: number | null; // null if the menu item was deleted later
  name: string;
  unitPriceCents: number;
  quantity: number;
  lineTotalCents: number;
};

export type OrderStatusEvent = {
  fromStatus: OrderStatus | null; // null for the event that created the order
  toStatus: OrderStatus;
  changedBy: number | null;
  createdAt: Date;
};

export type OrderDetail = Order & {
  items: OrderItem[];
  statusHistory: OrderStatusEvent[];
};
