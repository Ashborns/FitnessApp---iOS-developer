const admin = require("firebase-admin");
const path = require("path");
const serviceAccount = require(path.resolve(__dirname, "../TodolistApp/mytodolist-ce366-firebase-adminsdk-fbsvc-a60778d3da.json"));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();
db.listCollections().then(collections => {
  console.log("Firebase Collections available:", collections.map(c => c.id));
  process.exit(0);
});
