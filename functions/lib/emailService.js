const { Resend } = require('resend');
const functions = require('firebase-functions');

// Initialize Resend with API key from Firebase config
// Set via: firebase functions:config:set resend.api_key="re_..."
const RESEND_API_KEY = functions.config().resend?.api_key || process.env.RESEND_API_KEY;

let resend;
if (RESEND_API_KEY) {
  resend = new Resend(RESEND_API_KEY);
  console.log('✅ Resend email service initialized');
} else {
  console.warn('⚠️ WARNING: Resend API key not configured!');
  console.warn('   Production: Run "firebase functions:config:set resend.api_key=YOUR_KEY"');
  console.warn('   Local: Set RESEND_API_KEY in functions/.env');
}

/**
 * Email service for sending appointment notifications
 */
class EmailService {
  /**
   * Send booking confirmation email to patient
   * @param {Object} appointment - Appointment details
   * @param {string} patientEmail - Patient's email address
   * @returns {Promise<Object>} - Email send result
   */
  static async sendBookingConfirmation(appointment, patientEmail) {
    try {
      if (!resend) {
        throw new Error('Resend not initialized - API key missing');
      }

      const confirmationUrl = `https://us-central1-medx-ai.cloudfunctions.net/confirmAppointmentViaEmail?id=${appointment.id}`;
      
      const emailHtml = this._generateBookingConfirmationEmail(appointment, confirmationUrl);
      
      const result = await resend.emails.send({
        from: 'MedWave <onboarding@resend.dev>',
        to: patientEmail,
        subject: `Appointment Booking Confirmation - ${appointment.patientName}`,
        html: emailHtml,
      });

      console.log(`✅ Booking confirmation email sent to ${patientEmail}`, result);
      return { success: true, messageId: result?.id || result?.data?.id };
    } catch (error) {
      console.error('❌ Error sending booking confirmation email:', error);
      // Return error but don't throw to prevent function failure
      return { success: false, error: error.message || String(error) };
    }
  }

  /**
   * Send appointment confirmed email to patient
   * @param {Object} appointment - Appointment details
   * @param {string} patientEmail - Patient's email address
   * @returns {Promise<Object>} - Email send result
   */
  static async sendAppointmentConfirmed(appointment, patientEmail) {
    try {
      if (!resend) {
        throw new Error('Resend not initialized - API key missing');
      }

      const emailHtml = this._generateAppointmentConfirmedEmail(appointment);
      
      const result = await resend.emails.send({
        from: 'MedWave <onboarding@resend.dev>',
        to: patientEmail,
        subject: `Appointment Confirmed - ${appointment.patientName}`,
        html: emailHtml,
      });

      console.log(`✅ Appointment confirmed email sent to ${patientEmail}`, result);
      return { success: true, messageId: result?.id || result?.data?.id };
    } catch (error) {
      console.error('❌ Error sending appointment confirmed email:', error);
      return { success: false, error: error.message || String(error) };
    }
  }

  /**
   * Send appointment reminder email (24 hours before)
   * @param {Object} appointment - Appointment details
   * @param {string} patientEmail - Patient's email address
   * @returns {Promise<Object>} - Email send result
   */
  static async sendAppointmentReminder(appointment, patientEmail) {
    try {
      if (!resend) {
        throw new Error('Resend not initialized - API key missing');
      }

      const emailHtml = this._generateAppointmentReminderEmail(appointment);
      
      const result = await resend.emails.send({
        from: 'MedWave <onboarding@resend.dev>',
        to: patientEmail,
        subject: `Reminder: Appointment Tomorrow - ${appointment.patientName}`,
        html: emailHtml,
      });

      console.log(`✅ Appointment reminder email sent to ${patientEmail}`, result);
      return { success: true, messageId: result?.id || result?.data?.id };
    } catch (error) {
      console.error('❌ Error sending appointment reminder email:', error);
      return { success: false, error: error.message || String(error) };
    }
  }

  /**
   * Send appointment cancellation email
   * @param {Object} appointment - Appointment details
   * @param {string} patientEmail - Patient's email address
   * @returns {Promise<Object>} - Email send result
   */
  static async sendAppointmentCancellation(appointment, patientEmail) {
    try {
      if (!resend) {
        throw new Error('Resend not initialized - API key missing');
      }

      const emailHtml = this._generateAppointmentCancellationEmail(appointment);
      
      const result = await resend.emails.send({
        from: 'MedWave <onboarding@resend.dev>',
        to: patientEmail,
        subject: `Appointment Cancelled - ${appointment.patientName}`,
        html: emailHtml,
      });

      console.log(`✅ Appointment cancellation email sent to ${patientEmail}`, result);
      return { success: true, messageId: result?.id || result?.data?.id };
    } catch (error) {
      console.error('❌ Error sending appointment cancellation email:', error);
      return { success: false, error: error.message || String(error) };
    }
  }

  /**
   * Generate booking confirmation email HTML
   * @private
   */
  static _generateBookingConfirmationEmail(appointment, confirmationUrl) {
    const appointmentDate = new Date(appointment.startTime).toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    const appointmentTime = new Date(appointment.startTime).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });

    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Appointment Booking Confirmation</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 30px; text-align: center; border-radius: 8px 8px 0 0;">
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600;">MedWave</h1>
              <p style="margin: 10px 0 0 0; color: #ffffff; font-size: 16px; opacity: 0.9;">Appointment Booking Confirmation</p>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">Hi ${appointment.patientName},</h2>
              <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.6;">
                Your appointment has been successfully booked. Please confirm your attendance by clicking the button below.
              </p>
              
              <!-- Appointment Details Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 6px; margin: 20px 0;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📅 Date:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentDate}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">🕐 Time:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentTime}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">👨‍⚕️ Practitioner:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.practitionerName || 'To be assigned'}</span>
                        </td>
                      </tr>
                      ${appointment.location ? `
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📍 Location:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.location}</span>
                        </td>
                      </tr>
                      ` : ''}
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📋 Type:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.type}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              
              <!-- Confirmation Button -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td align="center">
                    <a href="${confirmationUrl}" style="display: inline-block; padding: 14px 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; border-radius: 6px; font-size: 16px; font-weight: 600;">
                      Confirm Appointment
                    </a>
                  </td>
                </tr>
              </table>
              
              <p style="margin: 20px 0 0 0; color: #999999; font-size: 14px; line-height: 1.6;">
                If the button doesn't work, copy and paste this link into your browser:<br>
                <a href="${confirmationUrl}" style="color: #667eea; word-break: break-all;">${confirmationUrl}</a>
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 20px 30px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; text-align: center;">
              <p style="margin: 0; color: #999999; font-size: 14px;">
                Need help? Contact us at <a href="mailto:support@medwave.app" style="color: #667eea; text-decoration: none;">support@medwave.app</a>
              </p>
              <p style="margin: 10px 0 0 0; color: #999999; font-size: 12px;">
                © ${new Date().getFullYear()} MedWave. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;
  }

  /**
   * Generate appointment confirmed email HTML
   * @private
   */
  static _generateAppointmentConfirmedEmail(appointment) {
    const appointmentDate = new Date(appointment.startTime).toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    const appointmentTime = new Date(appointment.startTime).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });

    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Appointment Confirmed</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 40px 30px; text-align: center; border-radius: 8px 8px 0 0;">
              <div style="font-size: 48px; margin-bottom: 10px;">✅</div>
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600;">Appointment Confirmed!</h1>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">Hi ${appointment.patientName},</h2>
              <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.6;">
                Great news! Your appointment has been confirmed. We look forward to seeing you.
              </p>
              
              <!-- Appointment Details Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 6px; margin: 20px 0;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📅 Date:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentDate}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">🕐 Time:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentTime}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">👨‍⚕️ Practitioner:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.practitionerName || 'To be assigned'}</span>
                        </td>
                      </tr>
                      ${appointment.location ? `
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📍 Location:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.location}</span>
                        </td>
                      </tr>
                      ` : ''}
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📋 Type:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.type}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              
              <!-- Reminder Notice -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #e8f5e9; border-left: 4px solid #4caf50; border-radius: 4px; margin: 20px 0;">
                <tr>
                  <td style="padding: 15px;">
                    <p style="margin: 0; color: #2e7d32; font-size: 14px; line-height: 1.6;">
                      <strong>📨 Reminder:</strong> You'll receive a reminder email 24 hours before your appointment.
                    </p>
                  </td>
                </tr>
              </table>
              
              <p style="margin: 20px 0 0 0; color: #666666; font-size: 14px; line-height: 1.6;">
                If you need to reschedule or cancel, please contact us at least 24 hours in advance.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 20px 30px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; text-align: center;">
              <p style="margin: 0; color: #999999; font-size: 14px;">
                Need help? Contact us at <a href="mailto:support@medwave.app" style="color: #11998e; text-decoration: none;">support@medwave.app</a>
              </p>
              <p style="margin: 10px 0 0 0; color: #999999; font-size: 12px;">
                © ${new Date().getFullYear()} MedWave. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;
  }

  /**
   * Generate appointment reminder email HTML
   * @private
   */
  static _generateAppointmentReminderEmail(appointment) {
    const appointmentDate = new Date(appointment.startTime).toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    const appointmentTime = new Date(appointment.startTime).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });

    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Appointment Reminder</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 40px 30px; text-align: center; border-radius: 8px 8px 0 0;">
              <div style="font-size: 48px; margin-bottom: 10px;">⏰</div>
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600;">Appointment Reminder</h1>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">Hi ${appointment.patientName},</h2>
              <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.6;">
                This is a friendly reminder that your appointment is scheduled for <strong>tomorrow</strong>.
              </p>
              
              <!-- Appointment Details Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #fff3e0; border-radius: 6px; margin: 20px 0; border: 2px solid #ff9800;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📅 Date:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentDate}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">🕐 Time:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentTime}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">👨‍⚕️ Practitioner:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.practitionerName || 'To be assigned'}</span>
                        </td>
                      </tr>
                      ${appointment.location ? `
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📍 Location:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.location}</span>
                        </td>
                      </tr>
                      ` : ''}
                    </table>
                  </td>
                </tr>
              </table>
              
              <!-- Important Notice -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #e3f2fd; border-left: 4px solid #2196f3; border-radius: 4px; margin: 20px 0;">
                <tr>
                  <td style="padding: 15px;">
                    <p style="margin: 0; color: #1565c0; font-size: 14px; line-height: 1.6;">
                      <strong>💡 Please arrive 10 minutes early</strong> to complete any necessary paperwork.
                    </p>
                  </td>
                </tr>
              </table>
              
              <p style="margin: 20px 0 0 0; color: #666666; font-size: 14px; line-height: 1.6;">
                If you need to reschedule or have any questions, please contact us as soon as possible.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 20px 30px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; text-align: center;">
              <p style="margin: 0; color: #999999; font-size: 14px;">
                Need help? Contact us at <a href="mailto:support@medwave.app" style="color: #f5576c; text-decoration: none;">support@medwave.app</a>
              </p>
              <p style="margin: 10px 0 0 0; color: #999999; font-size: 12px;">
                © ${new Date().getFullYear()} MedWave. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;
  }

  /**
   * Generate appointment cancellation email HTML
   * @private
   */
  static _generateAppointmentCancellationEmail(appointment) {
    const appointmentDate = new Date(appointment.startTime).toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    const appointmentTime = new Date(appointment.startTime).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });

    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Appointment Cancelled</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #868f96 0%, #596164 100%); padding: 40px 30px; text-align: center; border-radius: 8px 8px 0 0;">
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600;">MedWave</h1>
              <p style="margin: 10px 0 0 0; color: #ffffff; font-size: 16px; opacity: 0.9;">Appointment Cancelled</p>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px;">Hi ${appointment.patientName},</h2>
              <p style="margin: 0 0 20px 0; color: #666666; font-size: 16px; line-height: 1.6;">
                This email confirms that your appointment has been cancelled.
              </p>
              
              <!-- Appointment Details Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 6px; margin: 20px 0;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">📅 Date:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentDate}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">🕐 Time:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointmentTime}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <strong style="color: #333333; font-size: 14px;">👨‍⚕️ Practitioner:</strong>
                          <span style="color: #666666; font-size: 14px; margin-left: 10px;">${appointment.practitionerName || 'N/A'}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              
              <p style="margin: 20px 0 0 0; color: #666666; font-size: 14px; line-height: 1.6;">
                If you'd like to book a new appointment, please contact us or use the MedWave app.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 20px 30px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; text-align: center;">
              <p style="margin: 0; color: #999999; font-size: 14px;">
                Need help? Contact us at <a href="mailto:support@medwave.app" style="color: #667eea; text-decoration: none;">support@medwave.app</a>
              </p>
              <p style="margin: 10px 0 0 0; color: #999999; font-size: 12px;">
                © ${new Date().getFullYear()} MedWave. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;
  }
}

module.exports = { EmailService };

