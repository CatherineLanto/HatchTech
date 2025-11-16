const { onValueWritten } = require('firebase-functions/v2/database');
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

// Trigger whenever any incubator data changes
exports.sendSensorAlert = onValueWritten('/HatchTech/{incubatorId}', async (event) => {
  const beforeData = event.data.before.val();
  const newData = event.data.after.val();

  // Exit if no new data or nothing actually changed
  if (!newData || JSON.stringify(beforeData) === JSON.stringify(newData)) {
    return null;
  }

  const incubatorName = event.params.incubatorId;
  let notifications = [];

  // Temperature alerts
  if (newData.temperature > THRESHOLDS.tempHigh) {
    notifications.push(`Temperature too high: ${newData.temperature}°C`);
  } else if (newData.temperature < THRESHOLDS.tempLow) {
    notifications.push(`Temperature too low: ${newData.temperature}°C`);
  }

  // Humidity alerts
  if (newData.humidity > THRESHOLDS.humidityHigh) {
    notifications.push(`Humidity too high: ${newData.humidity}%`);
  } else if (newData.humidity < THRESHOLDS.humidityLow) {
    notifications.push(`Humidity too low: ${newData.humidity}%`);
  }

  // CO2 alert
  if (newData.co2 > THRESHOLDS.co2High) {
    notifications.push(`CO₂ level high: ${newData.co2} ppm`);
  }

  // Oxygen alert
  if (newData.oxygen < THRESHOLDS.oxygenLow) {
    notifications.push(`Oxygen level low: ${newData.oxygen}%`);
  }

  // If no alerts, exit quietly
  if (notifications.length === 0) {
    logger.info(`✅ No issues detected for ${incubatorName}`);
    return null;
  }

  // Combine alerts into one message
  const combinedBody = notifications.join('\n');

  // 🔹 Option 1: Send to ALL users (current behavior)
  const tokensSnapshot = await firestore.collection('users').get();

  // 🔹 Option 2: To send only to users who manage this incubator,
  // uncomment this line and remove the one above:
  // const tokensSnapshot = await firestore.collection('users')
  //   .where('incubators', 'array-contains', incubatorName)
  //   .get();

  const tokens = tokensSnapshot.docs
    .map(doc => doc.data().fcmToken)
    .filter(Boolean);

  if (tokens.length === 0) {
    logger.info('⚠️ No FCM tokens found.');
    return null;
  }

  // Build notification payload
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

  // Send notification using modern SDK method
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info(`✅ Sent ${response.successCount} notification(s) for ${incubatorName}`);
  } catch (error) {
    logger.error('❌ Error sending notification:', error);
  }

  return null;
});
