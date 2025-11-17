const { onValueWritten } = require('firebase-functions/v2/database');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const firestore = admin.firestore();

const THRESHOLDS = {
  tempHigh: 39,
  tempLow: 36.5,
  humidityHigh: 70,
  humidityLow: 40,
  co2High: 1000,
  oxygenLow: 19,
};

exports.sendSensorAlert = onValueWritten('/HatchTech/{incubatorId}', async (event) => {
  const beforeData = event.data.before.val();
  const newData = event.data.after.val();

  if (!newData || JSON.stringify(beforeData) === JSON.stringify(newData)) {
    return null;
  }

  const incubatorName = event.params.incubatorId;
  let notifications = [];

  if (newData.temperature > THRESHOLDS.tempHigh) {
    notifications.push(`Temperature too high: ${newData.temperature}°C`);
  } else if (newData.temperature < THRESHOLDS.tempLow) {
    notifications.push(`Temperature too low: ${newData.temperature}°C`);
  }

  if (newData.humidity > THRESHOLDS.humidityHigh) {
    notifications.push(`Humidity too high: ${newData.humidity}%`);
  } else if (newData.humidity < THRESHOLDS.humidityLow) {
    notifications.push(`Humidity too low: ${newData.humidity}%`);
  }

  if (newData.co2 > THRESHOLDS.co2High) {
    notifications.push(`CO₂ level high: ${newData.co2} ppm`);
  }

  if (newData.oxygen < THRESHOLDS.oxygenLow) {
    notifications.push(`Oxygen level low: ${newData.oxygen}%`);
  }

  if (notifications.length === 0) {
    logger.info(`✅ No issues detected for ${incubatorName}`);
    return null;
  }

  const combinedBody = notifications.join('\n');

  const tokensSnapshot = await firestore.collection('users').get();

  let tokens = [];

  tokensSnapshot.docs.forEach(doc => {
  const userTokens = doc.data().fcmTokens; 
  if (Array.isArray(userTokens)) {
    tokens = tokens.concat(userTokens.filter(Boolean));
  }
});

if (tokens.length === 0) {
  logger.info('⚠️ No FCM tokens found in the fcmTokens array.');
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
  
  if (response.failureCount > 0) {
    const failedTokens = [];
    response.responses.forEach((resp, index) => {
      if (!resp.success) {
        failedTokens.push({
          token: tokens[index],
          error: resp.error.code,
          message: resp.error.message,
        });
      }
    });
    logger.error(`❌ Failed to send to ${response.failureCount} device(s):`, JSON.stringify(failedTokens, null, 2));
  }

} catch (error) {
  logger.error('❌ FATAL Error sending notification:', error);
}

return null;
});