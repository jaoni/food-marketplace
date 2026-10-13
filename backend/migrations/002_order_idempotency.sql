-- POST /orders now requires an Idempotency-Key header. A retried request with
-- the same key returns the original order instead of creating a second one.

ALTER TABLE orders ADD COLUMN idempotency_key text;

-- Fingerprint (SHA-256) of the request body, used to detect a key being reused
-- for a different order.
ALTER TABLE orders ADD COLUMN request_hash text;

-- Orders created before this migration get a placeholder key, so that the
-- columns can be NOT NULL.
UPDATE orders
SET idempotency_key = 'legacy-' || id, request_hash = ''
WHERE idempotency_key IS NULL;

ALTER TABLE orders ALTER COLUMN idempotency_key SET NOT NULL;
ALTER TABLE orders ALTER COLUMN request_hash SET NOT NULL;

-- One customer can't use the same key twice. (Two different customers picking
-- the same key is fine.)
ALTER TABLE orders
  ADD CONSTRAINT orders_customer_id_idempotency_key_key UNIQUE (customer_id, idempotency_key);
