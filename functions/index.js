const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.database(); // Realtime Database
const firestore = admin.firestore(); // Firestore for storing tokens

// Thresholds (adjust to your needs)
const THRESHOLDS = {
    tempHigh: 39,
    tempLow: 36.5,
    humidityLow: 40,
    humidityHigh: 70,
    co2High: 1000,
    oxygenLow: 19
};

// Trigger when any incubator data changes
exports.sendSensorAlert = functions.database.ref('/HatchTech/{incubatorId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.val();
        if (!newData) return null;

        const incubatorName = context.params.incubatorId;
        let notifications = [];

        // Temperature
        if (newData.temperature > THRESHOLDS.tempHigh) {
            notifications.push({
                title: "🔥 Overheat Alert",
                body: `${incubatorName} temperature too high: ${newData.temperature}°C`
            });
        } else if (newData.temperature < THRESHOLDS.tempLow) {
            notifications.push({
                title: "❄️ Low Temperature",
                body: `${incubatorName} temperature too low: ${newData.temperature}°C`
            });
        }

        // Humidity
        if (newData.humidity > THRESHOLDS.humidityHigh) {
            notifications.push({
                title: "💦 High Humidity",
                body: `${incubatorName} humidity too high: ${newData.humidity}%`
            });
        } else if (newData.humidity < THRESHOLDS.humidityLow) {
            notifications.push({
                title: "💧 Low Humidity",
                body: `${incubatorName} humidity too low: ${newData.humidity}%`
            });
        }

        // CO2
        if (newData.co2 > THRESHOLDS.co2High) {
            notifications.push({
                title: "🌫️ CO₂ Alert",
                body: `${incubatorName} CO₂ level high: ${newData.co2} ppm`
            });
        }

        // Oxygen
        if (newData.oxygen < THRESHOLDS.oxygenLow) {
            notifications.push({
                title: "🫁 Low Oxygen Alert",
                body: `${incubatorName} oxygen low: ${newData.oxygen}%`
            });
        }

        if (notifications.length === 0) return null;

        // Get all FCM tokens from Firestore
        const tokensSnapshot = await firestore.collection('users').get();
        const tokens = tokensSnapshot.docs
            .map(doc => doc.data().fcmToken)
            .filter(token => !!token);

        if (tokens.length === 0) return null;

        // Send notifications to all tokens
        const messages = notifications.map(notif => ({
            notification: {
                title: notif.title,
                body: notif.body
            },
            tokens: tokens
        }));

        for (const message of messages) {
            try {
                const response = await admin.messaging().sendMulticast(message);
                console.log('Notifications sent:', response.successCount);
            } catch (error) {
                console.error('Error sending notifications:', error);
            }
        }

        return null;
    });
