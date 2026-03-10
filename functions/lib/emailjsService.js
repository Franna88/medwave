const axios = require('axios');
const functions = require('firebase-functions');

const EMAILJS_API_URL = 'https://api.emailjs.com/api/v1.0/email/send';

// Config from Firebase: emailjs.service_id, emailjs.user_id, emailjs.contract_reminder_template_id, emailjs.private_key (optional)
const getConfig = () => {
  const config = functions.config().emailjs || {};
  return {
    serviceId: config.service_id || process.env.EMAILJS_SERVICE_ID,
    userId: config.user_id || process.env.EMAILJS_USER_ID,
    contractReminderTemplateId:
      config.contract_reminder_template_id ||
      process.env.EMAILJS_CONTRACT_REMINDER_TEMPLATE_ID,
    privateKey: config.private_key || process.env.EMAILJS_PRIVATE_KEY,
  };
};

/**
 * Send contract signing reminder email via EmailJS
 * @param {Object} params
 * @param {string} params.toEmail - Recipient email
 * @param {string} params.customerName - Customer name
 * @param {string} params.contractLink - Full URL to sign contract
 * @param {number} params.reminderNumber - 1-5
 * @param {number} [params.daysSinceSent] - Days since contract was created
 * @param {string} [params.reminderOptInUrl] - URL for "yes, keep reminders"
 * @param {string} [params.reminderOptOutUrl] - URL for "no, stop reminders"
 * @returns {Promise<{success: boolean, error?: string}>}
 */
async function sendContractReminderEmail({
  toEmail,
  customerName,
  contractLink,
  reminderNumber,
  daysSinceSent,
  reminderOptInUrl,
  reminderOptOutUrl,
}) {
  const config = getConfig();

  if (!config.serviceId || !config.userId || !config.contractReminderTemplateId) {
    console.warn(
      '⚠️ EmailJS not configured. Set firebase functions:config:set emailjs.service_id=... emailjs.user_id=... emailjs.contract_reminder_template_id=...'
    );
    return { success: false, error: 'EmailJS not configured' };
  }

  const templateParams = {
    to_email: toEmail,
    email: toEmail,
    to_name: customerName,
    username: customerName,
    customer_name: customerName,
    contract_link: contractLink,
    reminder_number: String(reminderNumber),
    days_since_sent: daysSinceSent != null ? String(daysSinceSent) : '',
    reminder_opt_in_url: reminderOptInUrl || '',
    reminder_opt_out_url: reminderOptOutUrl || '',
  };

  const body = {
    service_id: config.serviceId,
    template_id: config.contractReminderTemplateId,
    user_id: config.userId,
    template_params: templateParams,
  };

  if (config.privateKey) {
    body.accessToken = config.privateKey;
  }

  try {
    const response = await axios.post(EMAILJS_API_URL, body, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 15000,
    });

    if (response.status === 200) {
      console.log(`✅ Contract reminder email sent to ${toEmail}`);
      return { success: true };
    }

    console.error(
      `❌ EmailJS returned ${response.status}:`,
      response.data
    );
    return {
      success: false,
      error: response.data?.message || `HTTP ${response.status}`,
    };
  } catch (err) {
    const status = err.response?.status;
    const msg = err.response?.data?.message || err.message || String(err);
    if (status === 403) {
      console.error(
        '❌ EmailJS 403: Server-side calls require a private key. Set emailjs.private_key in Firebase config.'
      );
    } else if (status === 429) {
      console.error('❌ EmailJS 429: Rate limit exceeded (1 req/sec). Emails are throttled.');
    }
    console.error('❌ Error sending contract reminder email:', msg);
    return { success: false, error: msg };
  }
}

module.exports = { sendContractReminderEmail, getConfig };
