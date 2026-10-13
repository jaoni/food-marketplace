import { NotFoundError } from "../errors.ts";

// Path params are strings. Something that isn't a positive whole number can't
// be an id, so it gets the same 404 as an id that doesn't exist.
export function parseId(value: string, resource: string): number {
  const id = Number(value);
  if (!/^\d+$/.test(value) || !Number.isSafeInteger(id) || id <= 0) {
    throw new NotFoundError(`${resource} not found`);
  }
  return id;
}
