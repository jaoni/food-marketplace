// Business rules. Knows nothing about HTTP (req/res) or SQL.
import { NotFoundError } from "../errors.ts";
import * as menuRepository from "../repositories/menuRepository.ts";
import * as restaurantRepository from "../repositories/restaurantRepository.ts";
import type { Menu, Restaurant } from "../types.ts";

export function listRestaurants(): Promise<Restaurant[]> {
  return restaurantRepository.findAll();
}

export async function getRestaurant(id: number): Promise<Restaurant> {
  const restaurant = await restaurantRepository.findById(id);
  if (!restaurant) {
    throw new NotFoundError("Restaurant not found");
  }
  return restaurant;
}

export async function getMenu(restaurantId: number): Promise<Menu> {
  const restaurant = await getRestaurant(restaurantId);

  // Promise.all runs both queries at the same time instead of one after the other.
  const [categories, items] = await Promise.all([
    menuRepository.findCategoriesByRestaurant(restaurant.id),
    menuRepository.findItemsByRestaurant(restaurant.id),
  ]);

  return {
    restaurantId: restaurant.id,
    categories: categories.map((category) => ({
      ...category,
      items: items.filter((item) => item.categoryId === category.id),
    })),
  };
}
