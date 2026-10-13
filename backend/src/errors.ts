// Errors that services throw when a business rule says no. Each one carries its
// HTTP status, and the error handler (src/middleware/errorHandler.ts) turns it
// into a JSON response, so routes don't need try/catch.

export class AppError extends Error {
  status = 500;
}

export class BadRequestError extends AppError {
  status = 400;
}

export class UnauthorizedError extends AppError {
  status = 401;
}

export class ForbiddenError extends AppError {
  status = 403;
}

export class NotFoundError extends AppError {
  status = 404;
}

export class ConflictError extends AppError {
  status = 409;
}

export class UnprocessableError extends AppError {
  status = 422;
}
