import { firestore } from "firebase-functions";
import { initializeApp, firestore as _firestore, messaging } from "firebase-admin";
initializeApp();

export const notifyIncubatorEvent = firestore
    .document("incubators/{incubatorId}")
    .onUpdate(async (change) => {
      const newData = change.after.data();

      // Example: Check for hatching/candling event
      const startDate = newData.startDate;
      const incubationDays = newData.incubationDays || 21;
      const now = Date.now();
      const daysElapsed = Math.floor((now - startDate) / (1000 * 60 * 60 * 24));
      const daysRemaining = incubationDays - daysElapsed;

      let message = null;
        if (daysRemaining <= 2 && daysRemaining > 0) {
          message = `${newData.batchName || "Batch"}: Only ${daysRemaining} day(s) left until hatching!`;
        }

        // Example: Check for warning
        if (
          newData.humidity < 35 || newData.humidity > 65 ||
          newData.temperature < 36 || newData.temperature > 39 ||
          newData.oxygen < 19 || newData.co2 > 900
        ) {
          message = `${newData.batchName || "Batch"}: Warning! Incubator needs attention.`;
        }

      if (message) {
          // Get user FCM token (assumes incubator has a userId field)
          const userId = newData.userId;
          const userDoc = await _firestore().collection("users").doc(userId).get();
          const fcmToken = userDoc.data().fcmToken;
          if (fcmToken) {
              await messaging().send({
                  token: fcmToken,
                  notification: {
                      title: "Incubator Alert",
                      body: message,
                    },
                });
            }
        }
      return null;
    });