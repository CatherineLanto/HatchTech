import fetch from "node-fetch";
import { GoogleAuth } from "google-auth-library";

// Load your Firebase service account key file
const auth = new GoogleAuth({
  keyFile: "service-account.json", // Path to your downloaded JSON file
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});

async function sendNotification() {
  const accessToken = await auth.getAccessToken();

  const response = await fetch(
    "https://fcm.googleapis.com/v1/projects/hatchtech-7fba8/messages:send",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: "ercbke1WQCShN1tF0Zb9vm:APA91bGNmf8Fu3akYt7mr-UynWg3jcU5NBc_N9b8H6nIcF8-Fklr2ewXhtgfqeHLn6REh44HGFyRUL3TAZbsdXC0U5xjXrDH9B9xDz5-3L9XHbUkr5TOgQo", // 🔁 Replace with your actual token
          notification: {
            title: "Test Temperature Alert",
            body: "Incubator 1 exceeded 39°C!",
          },
          data: {
            type: "sensor_alert",
          },
        },
      }),
    }
  );

  const data = await response.json();
  console.log("FCM Response:", data);
}

sendNotification().catch(console.error);
