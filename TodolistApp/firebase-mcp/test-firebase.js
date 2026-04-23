const admin = require("firebase-admin");
const path = require("path");
const serviceAccount = require(path.resolve(__dirname, "../TodolistApp/mytodolist-ce366-firebase-adminsdk-fbsvc-a60778d3da.json"));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();
db.listCollections().then(collections => {
  console.log("Firebase Collections:", collections.map(c => c.id));
  db.collection("users").limit(1).get().then(snap => {
      if (!snap.empty) {
          console.log("User Document Data:", snap.docs[0].id, snap.docs[0].data());
          db.collection("users").doc(snap.docs[0].id).collection("todos").limit(1).get().then(todoSnap => {
              if(!todoSnap.empty) {
                  console.log("Found Todo Item Data:", todoSnap.docs[0].id, todoSnap.docs[0].data());
              }
              process.exit(0);
          })
      } else {
          console.log("No user documents found.");
          process.exit(0);
      }
  });
}).catch(err => {
  console.error("Error accessing Firestore:", err);
  process.exit(1);
});
