// The order lifecycle as a state machine:
//
//   pending → accepted → preparing → ready → picked_up → delivered
//      ↓          ↓           ↓
//   cancelled  cancelled   cancelled
//
// Each entry lists the roles that may make that move. Moves that aren't
// listed are not allowed, and delivered/cancelled are final.
import type { OrderStatus, Role } from "../types.ts";

const TRANSITIONS: Record<OrderStatus, Partial<Record<OrderStatus, Role[]>>> = {
  pending: {
    accepted: ["restaurant_owner", "admin"],
    cancelled: ["customer", "restaurant_owner", "admin"],
  },
  accepted: {
    preparing: ["restaurant_owner", "admin"],
    cancelled: ["restaurant_owner", "admin"],
  },
  preparing: {
    ready: ["restaurant_owner", "admin"],
    cancelled: ["restaurant_owner", "admin"],
  },
  ready: {
    picked_up: ["courier", "admin"],
  },
  picked_up: {
    delivered: ["courier", "admin"],
  },
  delivered: {},
  cancelled: {},
};

// The roles allowed to move an order from `from` to `to`, or null if that
// move doesn't exist (e.g. delivered → pending).
export function rolesAllowedToMove(from: OrderStatus, to: OrderStatus): Role[] | null {
  return TRANSITIONS[from][to] ?? null;
}
