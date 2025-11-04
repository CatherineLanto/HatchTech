// The Cloud Functions for Firebase SDK to create triggers and host HTTP endpoints
const functions = require("firebase-functions");
// The Firebase Admin SDK to access the Realtime Database and send FCM
const admin = require("firebase-admin");

// Initialize the Firebase Admin SDK.
// Since this is a Cloud Function, it uses the default service account credentials
// and is automatically authorized for both RTDB and FCM.
admin.initializeApp();


// --- Helper Function to Fetch All FCM Tokens ---
/**
 * Fetches all FCM tokens stored under the '/fcmTokens' path in RTDB.
 * Assumes tokens are stored as { [userId]: tokenString, ... }
 * @returns {Promise<string[]>} Array of valid FCM token strings.
 */
async function getAllFCMTokens() {
    // 1. Fetch tokens from RTDB
    const tokensRef = admin.database().ref('/fcmTokens');
    const snapshot = await tokensRef.once('value');

    if (!snapshot.exists()) {
        functions.logger.log('No FCM tokens found in RTDB.');
        return [];
    }

    // 2. Map the token object into an array of token strings
    const tokensObject = snapshot.val();
    const tokensArray = Object.values(tokensObject);

    return tokensArray;
}

// ------------------------------------------------
// =============== SENSOR ALERTS ================
// ------------------------------------------------
exports.sensorAlert = functions.database
  .ref("/incubators/{incubatorId}/sensors/{sensorType}")
  .onUpdate(async (change, context) => {
    // Ensure the function is only triggered by value changes, not deletions
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
      // 1. Get all active FCM tokens
      const tokens = await getAllFCMTokens();
      if (tokens.length === 0) return null;

      // 2. Construct the Data-Only Payload
      // Note: Data-Only is essential for background app handling (no duplicates)
      const payload = {
        data: {
          title: alertTitle,
          body: alertBody,
          type: "sensor_alert",
          incubatorId: incubatorId,
          // Convert the sensor value to string as required by FCM data payload
          sensorValue: String(sensorValue), 
          sensorType: sensorType,
        },
      };

      // 3. Send to all registered devices
      try {
        const response = await admin.messaging().sendToDevice(tokens, payload);
        functions.logger.log(`✅ Sent ${sensorType} alert for incubator ${incubatorId}`, response.results);
      } catch (error) {
        functions.logger.error(`Error sending ${sensorType} alert:`, error);
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
    // Ensure the function is only triggered by value changes, not deletions
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
      // 1. Get all active FCM tokens
      const tokens = await getAllFCMTokens();
      if (tokens.length === 0) return null;

      // 2. Construct the Data-Only Payload
      const payload = {
        data: {
          title: alertTitle,
          body: alertBody,
          type: "maintenance_alert",
          incubatorId: incubatorId,
          status: newStatus,
        },
      };

      // 3. Send to all registered devices
      try {
        const response = await admin.messaging().sendToDevice(tokens, payload);
        functions.logger.log(`✅ Sent maintenance alert for incubator ${incubatorId}`, response.results);
      } catch (error) {
        functions.logger.error(`Error sending maintenance alert:`, error);
      }
    }
    
    return null;
  });