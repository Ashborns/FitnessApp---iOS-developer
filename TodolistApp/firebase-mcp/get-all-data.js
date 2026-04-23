const admin = require("firebase-admin");
const path = require("path");
const serviceAccount = require(path.resolve(__dirname, "../TodolistApp/mytodolist-ce366-firebase-adminsdk-fbsvc-a60778d3da.json"));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

async function checkAllData() {
  try {
    const authUsers = await admin.auth().listUsers(100);
    console.log(`Total users in Auth: ${authUsers.users.length}\n`);

    for (const user of authUsers.users) {
      console.log(`=== User: ${user.email} (UID: ${user.uid}) ===`);
      
      // Cek data profil di koleksi 'users'
      const userDoc = await db.collection("users").doc(user.uid).get();
      console.log("Firestore Profile:", userDoc.exists ? userDoc.data() : "[Tidak ada data profile di Firestore]");

      // Cek isi todo list di subkoleksi 'todos' milik user
      const todos = await db.collection("users").doc(user.uid).collection("todos").get();
      if (!todos.empty) {
        console.log(`Tasks/Todos (${todos.size}):`);
        todos.forEach(doc => console.log(` - [${doc.id}]:`, doc.data()));
      } else {
        console.log("Tasks/Todos: [Kosong]");
      }
      console.log("==================================================\n");
    }
    process.exit(0);
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}
checkAllData();
