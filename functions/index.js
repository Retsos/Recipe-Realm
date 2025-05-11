const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { DateTime } = require("luxon");

admin.initializeApp();

exports.scheduledMealNotifications = onSchedule(
    {
        schedule: "* * * * *", //*/5 fixxed times /9 /2 /7
        timeZone: "Europe/Athens",
        memory: "256MiB",
        timeoutSeconds: 60,
    },
    async (event) => {
        const utcNow = DateTime.now().toUTC();
        const currentHour = utcNow.hour;
        const currentMinute = utcNow.minute;
        const todayDate = utcNow.toISODate();

        console.log(`📅 Τρέχουσα ώρα Αθήνας: ${currentHour}:${currentMinute}, Ημερομηνία: ${todayDate}`);

        try {
            const usersSnapshot = await admin.firestore()
                .collection("User")
                .where("notificationsEnabled", "==", true)
                .get();

            console.log(`👤 Σύνολο χρηστών με enabled notifications: ${usersSnapshot.size}`);

            for (const userDoc of usersSnapshot.docs) {
                const user = userDoc.data();
                const fcmToken = user.fcmToken;
                if (!fcmToken) {
                    console.log(`⚠️ Χρήστης ${userDoc.id} δεν έχει fcmToken.`);
                    continue;
                }

                const mealTimes = user.mealNotificationTimes || [];
                const todayMeals = (user.weeklyPlans || {})[todayDate] || {};

                console.log(`📋 Χρήστης ${userDoc.id} έχει mealTimes:`, mealTimes);

                for (const meal of mealTimes) {
                    const match =
                        meal.hour === currentHour &&
                        (
                            meal.minute === currentMinute ||
                            meal.minute === (currentMinute - 1 + 60) % 60 ||
                            meal.minute === (currentMinute - 2 + 60) % 60
                        );

                    if (match) {
                        const plannedMeal = todayMeals[meal.mealType] || "something delicious!";
                        console.log(`✅ Matching ώρα για ${meal.mealType} στον χρήστη ${userDoc.id}. Στέλνουμε: ${plannedMeal}`);

                        try {
                            await admin.messaging().send({
                                token: fcmToken,
                                notification: {
                                    title: `${meal.mealType} Time!`,
                                    body: `Don't forget to eat: ${plannedMeal}`,
                                },
                                android: {
                                    priority: "high",
                                    notification: {
                                        channelId: "meal_reminders",
                                        icon: "ic_notification",
                                    },
                                },
                                apns: {
                                    payload: {
                                        aps: {
                                            sound: "default",
                                            badge: 1,
                                        },
                                    },
                                },
                            });

                            console.log(`📨 Εστάλη ειδοποίηση: ${meal.mealType} ➜ ${userDoc.id}`);
                        } catch (error) {
                            console.error(`❌ Αποτυχία αποστολής ειδοποίησης στον ${userDoc.id}:`, error);
                        }
                    } else {
                        console.log(`⏰ Δεν ταίριαξε ώρα για ${meal.mealType} ➜ ${meal.hour}:${meal.minute}`);
                    }
                }
            }

            return { success: true };
        } catch (error) {
            console.error("❌ Σφάλμα στην scheduledMealNotifications:", error);
            throw new Error("Failed to send scheduled meal notifications.");
        }
    }
);

// Inactivity Check - Κάθε μέρα στις 20:00
exports.dailyInactivityCheck = onSchedule(
    {
        schedule: "0 20 * * *", // Κάθε μέρα στις 20:00
        timeZone: "Europe/Athens",
        memory: "256MiB",
        timeoutSeconds: 60,
    },
    async (event) => {
        const twoDaysAgo = new Date();
        twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);

        console.log(`📅 Checking inactivity for users since: ${twoDaysAgo.toISOString()}`);

        const usersSnapshot = await admin.firestore()
            .collection("User")
            .where("notificationsEnabled", "==", true)
            .where("weeklyPlansLastUpdated", "<", admin.firestore.Timestamp.fromDate(twoDaysAgo))
            .get();

        console.log(`👤 Found ${usersSnapshot.size} inactive users`);

        for (const userDoc of usersSnapshot.docs) {
            const user = userDoc.data();
            const fcmToken = user.fcmToken;
            const userId = userDoc.id;

            if (!fcmToken) {
                console.log(`⚠️ No token for user ${userId}`);
                continue;
            }

            try {
                await admin.messaging().send({
                    token: fcmToken,
                    notification: {
                        title: "Meal Plan Reminder!",
                        body: "You haven't created a plan for tomorrow. Tap to fill it in!",
                    },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "meal_planning_reminders",
                            icon: "ic_notification",
                        },
                    },
                    apns: {
                        payload: { aps: { sound: "default", badge: 1 } },
                    },
                });

                console.log(`✅ Inactivity notification sent to user ${userId}`);
            } catch (error) {
                console.error(`❌ Error sending to ${userId}:`, error);

                if (error?.errorInfo?.code === 'messaging/registration-token-not-registered') {
                    await admin.firestore().collection('User').doc(userId).update({
                        fcmToken: admin.firestore.FieldValue.delete(),
                    });
                    console.log(`🧹 Removed invalid token for user ${userId}`);
                }
            }
        }
    }
);
