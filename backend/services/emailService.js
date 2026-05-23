/**
 * PulseTrack — Email Service
 * Uses Nodemailer to send OTP and password reset emails.
 * Configure SMTP via environment variables.
 */

const nodemailer = require('nodemailer');

let transporter = null;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      service: process.env.EMAIL_SERVICE || 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
  }
  return transporter;
}

/**
 * Send an OTP email.
 * @param {string} email - Recipient email
 * @param {string} otp - 6-digit OTP code
 * @param {string} name - User's first name
 * @param {string} purpose - 'verification', '2FA', or 'reset'
 */
async function sendOTPEmail(email, otp, name, purpose = 'verification') {
  const subjects = {
    verification: 'Verify your PulseTrack account',
    '2FA': 'Your PulseTrack 2FA code',
    reset: 'Reset your PulseTrack password',
  };

  const subject = subjects[purpose] || subjects.verification;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: 'Helvetica Neue', Arial, sans-serif; background: #0a0a0f; color: #e2e8f0; margin: 0; padding: 0; }
    .container { max-width: 480px; margin: 40px auto; background: #161a22; border-radius: 16px; overflow: hidden; }
    .header { background: linear-gradient(135deg, #ff4d4d, #800000); padding: 32px; text-align: center; }
    .header h1 { margin: 0; font-size: 28px; color: white; letter-spacing: -0.5px; }
    .body { padding: 32px; }
    .otp-box { background: #0a0a0f; border: 2px solid #ff4d4d; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
    .otp { font-size: 42px; font-weight: 900; letter-spacing: 12px; color: #ff4d4d; font-family: monospace; }
    .note { font-size: 13px; color: #718096; margin-top: 16px; }
    .footer { padding: 24px 32px; border-top: 1px solid rgba(255,255,255,0.07); font-size: 12px; color: #4a5568; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>💓 PulseTrack</h1>
    </div>
    <div class="body">
      <p>Hi ${name || 'there'},</p>
      <p>Use the following one-time passcode to complete your action:</p>
      <div class="otp-box">
        <div class="otp">${otp}</div>
      </div>
      <p class="note">⏱ This code expires in <strong>10 minutes</strong>.<br>
      If you didn't request this, you can safely ignore this email.</p>
    </div>
    <div class="footer">PulseTrack Health Monitor &mdash; Secure Email</div>
  </div>
</body>
</html>
`;

  await getTransporter().sendMail({
    from: `"PulseTrack" <${process.env.EMAIL_USER}>`,
    to: email,
    subject,
    html,
  });
}

async function sendPasswordResetEmail(email, otp, name) {
  return sendOTPEmail(email, otp, name, 'reset');
}

module.exports = { sendOTPEmail, sendPasswordResetEmail };
