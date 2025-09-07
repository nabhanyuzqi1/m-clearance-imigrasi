const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    // Set custom user claims
    await admin.auth().setCustomUserClaims(user.uid, {role: "user"});

    // Optionally, create a user document in Firestore
    const userRef = admin.firestore().collection("users").doc(user.uid);
    return userRef.set({
      email: user.email,
      uid: user.uid,
      role: "user",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Error in onUserCreate:", error);
  }
});