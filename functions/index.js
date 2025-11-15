const { onValueUpdated } = require('firebase-functions/v2/database');
const { onSchedule } = require("firebase-functions/v2/scheduler"); // 🚨 NEW IMPORT
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const firestore = admin.firestore();

// Thresholds for alert conditions
const THRESHOLDS = {
  tempHigh: 39,
  tempLow: 36.5,
  humidityHigh: 70,
  humidityLow: 40,
  co2High: 1000,
  oxygenLow: 19,
};

// Cooldown in minutes to prevent repeated alerts
const ALERT_COOLDOWN_MINUTES = 5;

// Helper to check cooldown
async function canSendAlert(incubatorId, type) {
  const docRef = firestore.collection('alertsCooldown').doc(incubatorId);
  const doc = await docRef.get();
  const now = Date.now();

  if (!doc.exists) return true;

  const lastAlerts = doc.data() || {};
  const lastTime = lastAlerts[type] || 0;

  return (now - lastTime) > ALERT_COOLDOWN_MINUTES * 60 * 1000;
}

async function updateAlertCooldown(incubatorId, type) {
  const docRef = firestore.collection('alertsCooldown').doc(incubatorId);
  await docRef.set({ [type]: Date.now() }, { merge: true });
}

// 🚨 NEW HELPER FUNCTION: Collects all unique tokens for users managing a given incubator
async function collectTokensForIncubator(incubatorId) {
    const tokensSnapshot = await firestore.collection('users')
        .where('incubators', 'array-contains', incubatorId)
        .get();

    return tokensSnapshot.docs.flatMap(doc => {
        const userData = doc.data();
        const tokensMap = userData.fcmTokens;
        
        if (tokensMap && typeof tokensMap === 'object') {
            return Object.values(tokensMap).filter(token => typeof token === 'string' && token.length > 0);
        }
        return [];
    });
}


// --- 1. SENSOR ALERT FUNCTION (EXISTING) ---
exports.sendSensorAlert = onValueUpdated('/HatchTech/{incubatorId}', async (event) => {
  const beforeData = event.data.before.val() || {};
  const newData = event.data.after.val();
  const incubatorName = event.params.incubatorId;

  if (!newData) return null;

  let notifications = [];

  // Temperature
  if (newData.temperature > THRESHOLDS.tempHigh && beforeData.temperature <= THRESHOLDS.tempHigh
      && await canSendAlert(incubatorName, 'temperatureHigh')) {
    notifications.push(`Temperature too high: ${newData.temperature}°C`);
    await updateAlertCooldown(incubatorName, 'temperatureHigh');
  } else if (newData.temperature < THRESHOLDS.tempLow && beforeData.temperature >= THRESHOLDS.tempLow
      && await canSendAlert(incubatorName, 'temperatureLow')) {
    notifications.push(`Temperature too low: ${newData.temperature}°C`);
    await updateAlertCooldown(incubatorName, 'temperatureLow');
  }

  // Humidity
  if (newData.humidity > THRESHOLDS.humidityHigh && beforeData.humidity <= THRESHOLDS.humidityHigh
      && await canSendAlert(incubatorName, 'humidityHigh')) {
    notifications.push(`Humidity too high: ${newData.humidity}%`);
    await updateAlertCooldown(incubatorName, 'humidityHigh');
  } else if (newData.humidity < THRESHOLDS.humidityLow && beforeData.humidity >= THRESHOLDS.humidityLow
      && await canSendAlert(incubatorName, 'humidityLow')) {
    notifications.push(`Humidity too low: ${newData.humidity}%`);
    await updateAlertCooldown(incubatorName, 'humidityLow');
  }

  // CO2
  if (newData.co2 > THRESHOLDS.co2High && beforeData.co2 <= THRESHOLDS.co2High
      && await canSendAlert(incubatorName, 'co2High')) {
    notifications.push(`CO₂ level high: ${newData.co2} ppm`);
    await updateAlertCooldown(incubatorName, 'co2High');
  }

  // Oxygen
  if (newData.oxygen < THRESHOLDS.oxygenLow && beforeData.oxygen >= THRESHOLDS.oxygenLow
      && await canSendAlert(incubatorName, 'oxygenLow')) {
    notifications.push(`Oxygen level low: ${newData.oxygen}%`);
    await updateAlertCooldown(incubatorName, 'oxygenLow');
  }

  if (notifications.length === 0) {
    logger.info(`✅ No new alerts for ${incubatorName}`);
    return null;
  }

  const combinedBody = notifications.join('\n');

  // Use the helper to collect tokens
  const tokens = await collectTokensForIncubator(incubatorName);

  if (tokens.length === 0) {
    logger.info('⚠️ No FCM tokens found for this incubator.');
    return null;
  }

  const message = {
    notification: {
      title: `⚠️ ${incubatorName} Alert`,
      body: combinedBody,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'hatchtech_alerts',
        sound: 'default',
      },
    },
    data: { type: 'sensor_alert' },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info(`✅ Sent ${response.successCount} notification(s) for ${incubatorName}`);
  } catch (error) {
    logger.error('❌ Error sending notification:', error);
  }

  return null;
});

// ----------------------------------------------------------------------
// --- 2. SCHEDULED BATCH AND CANDLING REMINDERS (NEW) ---
// Runs daily at midnight UTC
exports.batchReminders = onSchedule('0 0 * * *', async (event) => {
    logger.info("Running daily batch and candling reminders.");

    const now = Date.now();
    const allReminders = [];
    const incubatorRemindersMap = new Map(); // Map to group reminders by incubator

    // 1. Query Firestore for all active batches
    const snapshot = await firestore.collection('batchHistory')
        .where('isDone', '==', false)
        .get();

    for (const doc of snapshot.docs) {
        const data = doc.data();
        const batchName = data.batchName || 'Unnamed Batch';
        const incubatorName = data.incubatorName || 'Unknown Incubator';
        const incubationDays = data.incubationDays || 21;
        const startDateMillis = data.startDate;

        if (!startDateMillis) continue;

        const startDate = new Date(startDateMillis);
        const hatchDate = new Date(startDate.getTime() + incubationDays * 24 * 60 * 60 * 1000);
        const daysToHatch = Math.ceil((hatchDate.getTime() - now) / (1000 * 3600 * 24));
        
        let reminderBody = null;

        // A. Hatching Reminder Check (1 day or less remaining)
        if (daysToHatch <= 1 && daysToHatch >= 0) {
            reminderBody = `🐣 Hatching: ${batchName} will hatch in ${daysToHatch} day(s)!`;
        }

        // B. Candling Reminder Check
        if (data.candlingDates && typeof data.candlingDates === 'object') {
            const daysSinceStart = Math.floor((now - startDate.getTime()) / (1000 * 3600 * 24));
            
            for (const [day, done] of Object.entries(data.candlingDates)) {
                const candlingDay = parseInt(day);
                // Check if candling is not done AND the day is due
                if (!done && !isNaN(candlingDay) && daysSinceStart >= candlingDay) {
                    reminderBody = `🔦 Candling: ${batchName} is due for candling (Day ${candlingDay}).`;
                    break; 
                }
            }
        }
        
        if (reminderBody) {
            // Group reminders by incubator to send one combined notification per incubator
            if (!incubatorRemindersMap.has(incubatorName)) {
                incubatorRemindersMap.set(incubatorName, []);
            }
            incubatorRemindersMap.get(incubatorName).push(reminderBody);
        }
    }

    if (incubatorRemindersMap.size === 0) {
        logger.info('✅ No batch or candling reminders are due today.');
        return null;
    }

    // 2. Send Notifications for each incubator with reminders
    for (const [incubatorName, reminders] of incubatorRemindersMap.entries()) {
        const tokens = await collectTokensForIncubator(incubatorName);

        if (tokens.length > 0) {
            const combinedBody = reminders.join('\n');
            const message = {
                notification: { title: `📅 ${incubatorName} Reminder`, body: combinedBody },
                android: { 
                    priority: 'high', 
                    notification: { channelId: 'hatchtech_batch_reminders' } 
                },
                data: { type: 'batch_reminder' },
                tokens: tokens,
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            logger.info(`✅ Sent ${response.successCount} batch/candling notification(s) for ${incubatorName}`);
        } else {
            logger.warn(`⚠️ No FCM tokens found for batch reminders on ${incubatorName}.`);
        }
    }

    return null;
});

// ----------------------------------------------------------------------
// --- 3. MAINTENANCE ALERT FUNCTION (NEW) ---
exports.sendMaintenanceAlert = onValueUpdated('/HatchTech/{incubatorId}/maintenance', async (event) => {
    const beforeData = event.data.before.val() || {};
    const newData = event.data.after.val();
    const incubatorName = event.params.incubatorId;

    if (!newData) return null;

    let notifications = [];

    const maintenanceItems = [
        { key: 'fan', label: 'Fan' },
        { key: 'sensor', label: 'Sensor' },
        { key: 'motor', label: 'Motor' },
    ];

    for (const item of maintenanceItems) {
        const alertType = `maintenance${item.label}`;
        const newStatus = newData[item.key];
        const beforeStatus = beforeData[item.key];
        
        // Trigger if a maintenance status appears AND cooldown is met
        if (newStatus && !beforeStatus && await canSendAlert(incubatorName, alertType)) {
            notifications.push(`⚠️ Predictive Maintenance: ${item.label}: ${newStatus}`);
            await updateAlertCooldown(incubatorName, alertType);
        }
        // Note: Resetting the cooldown is handled by your flutter app when the field is deleted/reset.
    }

    if (notifications.length === 0) {
        logger.info(`✅ No new maintenance alerts for ${incubatorName}`);
        return null;
    }

    const combinedBody = notifications.join('\n');
    const tokens = await collectTokensForIncubator(incubatorName);

    if (tokens.length === 0) {
        logger.info('⚠️ No FCM tokens found for maintenance alert recipients.');
        return null;
    }

    const message = {
        notification: {
            title: `🛠️ ${incubatorName} Maintenance Alert`,
            body: combinedBody,
        },
        android: {
            priority: 'high',
            notification: {
                channelId: 'hatchtech_maintenance_alerts', // Use the specific channel defined in Flutter
                sound: 'default',
            },
        },
        data: { type: 'maintenance_alert' },
        tokens: tokens,
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        logger.info(`✅ Sent ${response.successCount} maintenance notification(s) for ${incubatorName}`);
    } catch (error) {
        logger.error('❌ Error sending maintenance notification:', error);
    }

    return null;
});