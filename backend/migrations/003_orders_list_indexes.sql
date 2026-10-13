-- Indexes for GET /orders, which pages through orders newest first:
--   WHERE customer_id = ? AND id < ? ORDER BY id DESC LIMIT ?
-- An index on (customer_id, id) lets Postgres jump straight to those rows,
-- already in order, and stop as soon as it has enough. It also serves plain
-- "WHERE customer_id = ?" lookups, so the single-column indexes can go.

CREATE INDEX orders_customer_id_id_idx ON orders (customer_id, id);
CREATE INDEX orders_restaurant_id_id_idx ON orders (restaurant_id, id);

DROP INDEX orders_customer_id_idx;
DROP INDEX orders_restaurant_id_idx;
