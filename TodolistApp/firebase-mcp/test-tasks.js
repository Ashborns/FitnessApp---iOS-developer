const admin = require("firebase-admin");
const path = require("path");
const serviceAccount = require(path.resolve(__dirname, "../TodolistApp/mytodolist-ce366-firebase-adminsdk-fbsvc-a60778d3da.json"));
if (!admin.apps.length) {
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
}
const db = admin.firestore();
db.collection("todos").get().then(snap => {
      if (!snap.empty) {
          console.log("Todos in root:");
          snap.forEach(doc => {
             console.log(doc.id, doc.data());
          });
          process.exit(0);
      } else {
          console.log("No tasks found in the root 'todos' collection.");
          process.exit(0);
      }
}).catch(err => {
  console.error("Error accessing Firestore:", err);
  process.exit(1);
});
