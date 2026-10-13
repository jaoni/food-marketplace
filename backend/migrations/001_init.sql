-- Initial schema for Stage 1.
-- Money is stored as integer cents. IDs are bigint identity columns.

CREATE TABLE users (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email         text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  name          text NOT NULL,
  role          text NOT NULL CHECK (role IN ('customer', 'restaurant_owner', 'courier', 'admin')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE restaurants (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner_id   bigint NOT NULL REFERENCES users (id),
  name       text NOT NULL,
  is_open    boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX restaurants_owner_id_idx ON restaurants (owner_id);

CREATE TABLE menu_categories (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id bigint NOT NULL REFERENCES restaurants (id) ON DELETE CASCADE,
  name          text NOT NULL,
  sort_order    integer NOT NULL DEFAULT 0
);
CREATE INDEX menu_categories_restaurant_id_idx ON menu_categories (restaurant_id);

CREATE TABLE menu_items (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category_id  bigint NOT NULL REFERENCES menu_categories (id) ON DELETE CASCADE,
  name         text NOT NULL,
  description  text NOT NULL DEFAULT '',
  price_cents  integer NOT NULL CHECK (price_cents >= 0),
  is_available boolean NOT NULL DEFAULT true,
  sort_order   integer NOT NULL DEFAULT 0
);
CREATE INDEX menu_items_category_id_idx ON menu_items (category_id);

-- The allowed order statuses, defined once and reused by several columns.
CREATE DOMAIN order_status AS text
  CHECK (VALUE IN ('pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'cancelled'));

CREATE TABLE orders (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id      bigint NOT NULL REFERENCES users (id),
  restaurant_id    bigint NOT NULL REFERENCES restaurants (id),
  status           order_status NOT NULL DEFAULT 'pending',
  delivery_address text NOT NULL,
  total_cents      integer NOT NULL CHECK (total_cents >= 0),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_customer_id_idx ON orders (customer_id);
CREATE INDEX orders_restaurant_id_idx ON orders (restaurant_id);

-- Each line copies the item's name and price at order time, so later menu
-- changes never alter past orders. menu_item_id is only a reference.
CREATE TABLE order_items (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id         bigint NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  menu_item_id     bigint REFERENCES menu_items (id) ON DELETE SET NULL,
  name             text NOT NULL,
  unit_price_cents integer NOT NULL CHECK (unit_price_cents >= 0),
  quantity         integer NOT NULL CHECK (quantity > 0),
  line_total_cents integer NOT NULL CHECK (line_total_cents = unit_price_cents * quantity)
);
CREATE INDEX order_items_order_id_idx ON order_items (order_id);

-- One row per status change. from_status is NULL for the first event
-- (when the order is created).
CREATE TABLE order_status_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id    bigint NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  from_status order_status,
  to_status   order_status NOT NULL,
  changed_by  bigint REFERENCES users (id),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_status_events_order_id_idx ON order_status_events (order_id);
