"use strict";

const admin = require("firebase-admin");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendIncomingCallNotification = onDocumentCreated(
  {
    document: "calls/{callId}",
    region: "asia-south1",
  },
  async (event) => {
    const snapshot = event.data;
    const callId = event.params.callId;

    if (!snapshot) {
      logger.warn("Call create event did not include a snapshot.", {callId});
      return;
    }

    const call = snapshot.data() || {};

    if (call.status !== "ringing") {
      logger.info("Skipping non-ringing call notification.", {
        callId,
        status: call.status,
      });
      return;
    }

    if (!call.receiverId || typeof call.receiverId !== "string") {
      logger.warn("Skipping call notification without receiverId.", {callId});
      await markPushResult(callId, {
        pushStatus: "missing_receiver",
        pushAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const receiverSnapshot = await db
      .collection("users")
      .doc(call.receiverId)
      .get();

    if (!receiverSnapshot.exists) {
      logger.warn("Skipping call notification; receiver user not found.", {
        callId,
        receiverId: call.receiverId,
      });
      await markPushResult(callId, {
        pushStatus: "receiver_not_found",
        pushAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const receiver = receiverSnapshot.data() || {};
    const tokens = collectTokens(receiver);

    if (tokens.length === 0) {
      logger.warn("Skipping call notification; receiver has no FCM tokens.", {
        callId,
        receiverId: call.receiverId,
      });
      await markPushResult(callId, {
        pushStatus: "no_tokens",
        pushAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const callType = call.callType === "video" ? "video" : "audio";
    const callerName = stringOrDefault(call.callerName, "Someone");
    const title = `Incoming ${callType} call`;
    const body = `${callerName} is calling you`;

    const multicastMessage = {
      tokens,
      data: stringifyData({
        type: "incoming_call",
        callId,
        callerId: call.callerId,
        callerName,
        receiverId: call.receiverId,
        channelId: call.channelId || callId,
        callType,
        token: call.token,
        notificationTitle: title,
        notificationBody: body,
      }),
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(multicastMessage);
    const invalidTokens = tokens.filter((_, index) => {
      const errorCode = response.responses[index]?.error?.code;
      return errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered";
    });

    if (invalidTokens.length > 0) {
      await removeInvalidTokens(call.receiverId, invalidTokens, receiver);
    }

    await markPushResult(callId, {
      pushStatus: response.successCount > 0 ? "sent" : "failed",
      pushAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      pushSuccessCount: response.successCount,
      pushFailureCount: response.failureCount,
      pushTokenCount: tokens.length,
    });

    logger.info("Incoming call push completed.", {
      callId,
      receiverId: call.receiverId,
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidTokenCount: invalidTokens.length,
    });
  },
);

function collectTokens(user) {
  const tokens = new Set();

  if (typeof user.fcmToken === "string" && user.fcmToken.trim() !== "") {
    tokens.add(user.fcmToken.trim());
  }

  if (Array.isArray(user.fcmTokens)) {
    for (const token of user.fcmTokens) {
      if (typeof token === "string" && token.trim() !== "") {
        tokens.add(token.trim());
      }
    }
  }

  return Array.from(tokens);
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)]),
  );
}

function stringOrDefault(value, fallback) {
  if (typeof value !== "string" || value.trim() === "") return fallback;
  return value.trim();
}

async function markPushResult(callId, result) {
  try {
    await db.collection("calls").doc(callId).set(result, {merge: true});
  } catch (error) {
    logger.warn("Failed to write call push result metadata.", {
      callId,
      error,
    });
  }
}

async function removeInvalidTokens(userId, invalidTokens, user) {
  const updates = {
    fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
  };

  if (invalidTokens.includes(user.fcmToken)) {
    updates.fcmToken = admin.firestore.FieldValue.delete();
  }

  await db.collection("users").doc(userId).set(updates, {merge: true});
}
