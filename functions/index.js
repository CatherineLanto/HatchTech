const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// =============== SENSOR ALERTS ===============
exports.sensorAlert = functions.database
  .ref("/incubators/{incubatorId}/sensors/{sensorType}")
  .onUpdate(async (change, context) => {
    const sensorValue = change.after.val();
    const sensorType = context.params.sensorType;
    const incubatorId = context.params.incubatorId;

    let alertTitle = "";
    let alertBody = "";

    if (sensorType === "temperature" && sensorValue > 39.5) {
      alertTitle = "🔥 High Temperature Alert";
      alertBody = `Incubator ${incubatorId} temperature is ${sensorValue}°C! Cooling activated.`;
    } else if (sensorType === "humidity" && sensorValue < 40) {
      alertTitle = "💧 Low Humidity Alert";
      alertBody = `Incubator ${incubatorId} humidity dropped to ${sensorValue}%. Humidifier on.`;
    } else if (sensorType === "gas" && sensorValue > 200) {
      alertTitle = "☣️ Air Quality Alert";
      alertBody = `Incubator ${incubatorId} detected high gas level: ${sensorValue}ppm.`;
    }

    if (alertTitle !== "") {
      const tokensSnapshot = await admin.firestore().collection("users").get();
      const tokens = tokensSnapshot.docs.map(doc => doc.data().fcmToken);

      const payload = {
        data: {
          title: alertTitle,
          body: alertBody,
          type: "sensor_alert",
          incubatorId: incubatorId,
        },
      };

      await admin.messaging().sendToDevice(tokens, payload);
      console.log(`✅ Sent ${sensorType} alert for incubator ${incubatorId}`);
    }
  });
  
// =============== MAINTENANCE ALERTS ===============
exports.maintenanceAlert = functions.database
  .ref("/incubators/{incubatorId}/maintenance/status")
  .onUpdate(async (change, context) => {
    const newStatus = change.after.val();
    const incubatorId = context.params.incubatorId;

    let alertTitle = "";
    let alertBody = "";

    if (newStatus === "due") {
      alertTitle = "🧰 Maintenance Due";
      alertBody = `Incubator ${incubatorId} requires scheduled maintenance.`;
    } else if (newStatus === "fault") {
      alertTitle = "⚠️ Equipment Fault Detected";
      alertBody = `A possible malfunction was detected in Incubator ${incubatorId}.`;
    }

    if (alertTitle !== "") {
      const tokensSnapshot = await admin.firestore().collection("users").get();
      const tokens = tokensSnapshot.docs.map(doc => doc.data().fcmToken);

      const payload = {
        data: {
          title: alertTitle,
          body: alertBody,
          type: "maintenance_alert",
          incubatorId: incubatorId,
        },
      };

      await admin.messaging().sendToDevice(tokens, payload);
      console.log(`✅ Sent maintenance alert for incubator ${incubatorId}`);
    }
  });
