/**
 * PulseTrack — Input Validation Middleware
 * Uses express-validator to run declared rules and return structured errors.
 */

const { validationResult } = require('express-validator');

function validateRequest(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const firstError = errors.array()[0];
    return res.status(422).json({
      success: false,
      message: firstError.msg,
      field: firstError.path,
      errors: errors.array().map(e => ({ field: e.path, message: e.msg })),
    });
  }
  next();
}

module.exports = { validateRequest };
