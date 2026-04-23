const admin = require("firebase-admin");
const path = require("path");
const serviceAccount = require(path.resolve(__dirname, "../TodolistApp/mytodolist-ce366-firebase-adminsdk-fbsvc-a60778d3da.json"));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

admin.auth().listUsers(100)
  .then((listUsersResult) => {
    console.log(`Total users in Firebase Authentication: ${listUsersResult.users.length}`);
    listUsersResult.users.forEach((userRecord) => {
      console.log('User:', userRecord.toJSON());
    });
    process.exit(0);
  })
  .catch((error) => {
    console.log('Error listing users:', error);
    process.exit(1);
  });
