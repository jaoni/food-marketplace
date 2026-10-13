// SQL only. No HTTP and no business rules here.
import { pool } from "../db/pool.ts";
import type { MenuItem } from "../types.ts";

export async function findCategoriesByRestaurant(
  restaurantId: number,
): Promise<{ id: number; name: string }[]> {
  const { rows } = await pool.query<{ id: number; name: string }>(
    `SELECT id, name FROM menu_categories
     WHERE restaurant_id = $1
     ORDER BY sort_order, id`,
    [restaurantId],
  );
  return rows;
}

export async function findItemsByRestaurant(restaurantId: number): Promise<MenuItem[]> {
  const { rows } = await pool.query<MenuItem>(
    `SELECT mi.id, mi.category_id AS "categoryId", mi.name, mi.description,
            mi.price_cents AS "priceCents", mi.is_available AS "isAvailable"
     FROM menu_items mi
     JOIN menu_categories mc ON mc.id = mi.category_id
     WHERE mc.restaurant_id = $1
     ORDER BY mi.sort_order, mi.id`,
    [restaurantId],
  );
  return rows;
}

// The menu items with these ids that belong to this restaurant. Ids that don't
// exist, or belong to another restaurant, are simply missing from the result.
export async function findItemsByIds(restaurantId: number, itemIds: number[]): Promise<MenuItem[]> {
  const { rows } = await pool.query<MenuItem>(
    `SELECT mi.id, mi.category_id AS "categoryId", mi.name, mi.description,
            mi.price_cents AS "priceCents", mi.is_available AS "isAvailable"
     FROM menu_items mi
     JOIN menu_categories mc ON mc.id = mi.category_id
     WHERE mc.restaurant_id = $1 AND mi.id = ANY($2::bigint[])`,
    [restaurantId, itemIds],
  );
  return rows;
}
