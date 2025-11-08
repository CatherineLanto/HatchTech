// The Cloud Functions for Firebase SDK
const functions = require("firebase-functions");
// The Firebase Admin SDK to access RTDB and FCM
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK (uses default service account)
admin.initializeApp();

// --- Helper Function to Fetch All FCM Tokens ---
async function getAllFCMTokens() {
  const snapshot = await admin.database().ref("/fcmTokens").once("value");

  if (!snapshot.exists()) {
    functions.logger.log("⚠️ No FCM tokens found in RTDB.");
    return [];
  }

  const tokens = Object.values(snapshot.val() || {});
  return tokens;
}

// ------------------------------------------------
// =============== SENSOR ALERTS ==================
// ------------------------------------------------
exports.sensorAlert = functions.database
  .ref("/incubators/{incubatorId}/sensors/{sensorType}")
  .onUpdate(async (change, context) => {
    if (!change.after.exists()) return null;

    const sensorValue = change.after.val();
    const sensorType = context.params.sensorType;
    const incubatorId = context.params.incubatorId;

    let alertTitle = "";
    let alertBody = "";
    let shouldAlert = false;

    // --- ALERT LOGIC ---
    if (sensorType === "temperature" && sensorValue > 39.5) {
      alertTitle = "🔥 High Temperature Alert";
      alertBody = `Incubator ${incubatorId} temperature is ${sensorValue}°C! Cooling activated.`;
      shouldAlert = true;
    } else if (sensorType === "humidity" && sensorValue < 40) {
      alertTitle = "💧 Low Humidity Alert";
      alertBody = `Incubator ${incubatorId} humidity dropped to ${sensorValue}%. Humidifier on.`;
      shouldAlert = true;
    } else if (sensorType === "gas" && sensorValue > 200) {
      alertTitle = "☣️ Air Quality Alert";
      alertBody = `Incubator ${incubatorId} detected high gas level: ${sensorValue}ppm.`;
      shouldAlert = true;
    }

    if (shouldAlert) {
      const tokens = await getAllFCMTokens();
      if (tokens.length === 0) return null;

      const payload = {
        notification: {
          title: alertTitle,
          body: alertBody,
        },
        data: {
          title: alertTitle,
          body: alertBody,
          type: "sensor_alert",
          incubatorId: incubatorId,
          sensorValue: String(sensorValue),
          sensorType: sensorType,
        },
      };

      const options = {
        priority: "high",
        timeToLive: 60 * 60, // 1 hour
      };

      try {
        const response = await admin.messaging().sendToDevice(tokens, payload, options);
        functions.logger.log(`✅ Sent ${sensorType} alert for incubator ${incubatorId}`, response.results);
      } catch (error) {
        functions.logger.error(`❌ Error sending ${sensorType} alert:`, error);
      }
    }

    return null;
  });

// ---------------------------------------------------
// =============== MAINTENANCE ALERTS ================
// ---------------------------------------------------
exports.maintenanceAlert = functions.database
  .ref("/incubators/{incubatorId}/maintenance/status")
  .onUpdate(async (change, context) => {
    if (!change.after.exists()) return null;

    const newStatus = change.after.val();
    const incubatorId = context.params.incubatorId;

    let alertTitle = "";
    let alertBody = "";
    let shouldAlert = false;

    // --- ALERT LOGIC ---
    if (newStatus === "due") {
      alertTitle = "🧰 Maintenance Due";
      alertBody = `Incubator ${incubatorId} requires scheduled maintenance.`;
      shouldAlert = true;
    } else if (newStatus === "fault") {
      alertTitle = "⚠️ Equipment Fault Detected";
      alertBody = `A possible malfunction was detected in Incubator ${incubatorId}.`;
      shouldAlert = true;
    }

    if (shouldAlert) {
      const tokens = await getAllFCMTokens();
      if (tokens.length === 0) return null;

      const payload = {
        notification: {
          title: alertTitle,
          body: alertBody,
        },
        data: {
          title: alertTitle,
          body: alertBody,
          type: "maintenance_alert",
          incubatorId: incubatorId,
          status: newStatus,
        },
      };

      const options = {
        priority: "high",
        timeToLive: 60 * 60,
      };

      try {
        const response = await admin.messaging().sendToDevice(tokens, payload, options);
        functions.logger.log(`✅ Sent maintenance alert for incubator ${incubatorId}`, response.results);
      } catch (error) {
        functions.logger.error(`❌ Error sending maintenance alert:`, error);
      }
    }

    return null;
  });
