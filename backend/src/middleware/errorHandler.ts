import type { ErrorRequestHandler, RequestHandler } from "express";
import { ZodError } from "zod";
import { AppError } from "../errors.ts";

// Runs when no route matched. Express's default is an HTML page; we want JSON.
export const notFoundHandler: RequestHandler = (req, res) => {
  res.status(404).json({ error: "Not found" });
};

// Express calls this when a route throws (or its async function rejects).
// It must take 4 parameters, which is how Express recognises an error handler.
export const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  if (res.headersSent) {
    next(err);
    return;
  }

  if (err instanceof AppError) {
    res.status(err.status).json({ error: err.message });
    return;
  }

  // Request body failed zod validation.
  if (err instanceof ZodError) {
    res.status(400).json({
      error: "Invalid request",
      details: err.issues.map((issue) => ({
        path: issue.path.map(String).join("."),
        message: issue.message,
      })),
    });
    return;
  }

  // Errors from express.json(), like malformed JSON (400) or a body that's too
  // big (413). `expose: true` marks their messages as safe to show the client.
  if (err.expose === true && typeof err.status === "number") {
    res.status(err.status).json({ error: err.message });
    return;
  }

  // Anything else is a bug or an outage: log the details, return a generic message.
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
};
