const admin = require("firebase-admin");
const path = require("path");
const serviceAccount = require(path.resolve(__dirname, "../TodolistApp/mytodolist-ce366-firebase-adminsdk-fbsvc-a60778d3da.json"));
if (!admin.apps.length) {
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
}
const db = admin.firestore();
db.collection("users").count().get().then(snap => {
      console.log(`Total users in Firebase: ${snap.data().count}`);
      process.exit(0);
}).catch(err => {
  console.error("Error accessing Firestore:", err);
  process.exit(1);
});
