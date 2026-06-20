const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ₹100 maintenance balance kept in every rider's wallet.
const FLOOR = 100;

/**
 * Daily rider auto-payout — runs every morning at 08:00 IST.
 *
 * For each approved rider with wallet_balance > ₹100, it pays out the amount
 * above ₹100 by:
 *   • creating a `withdrawal_requests` doc (status: pending, is_auto: true)
 *     using the rider's most recent bank details,
 *   • setting wallet_balance back to ₹100,
 *   • logging a `wallet_transactions` debit.
 *
 * NOTE: this RECORDS the payout. The actual bank transfer must be settled by a
 * payout provider (Razorpay X / Cashfree Payouts / bank file) processing the
 * resulting `pending` rows. Riders with no bank on file are skipped.
 */
exports.dailyAutoPayout = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const ridersSnap = await db
      .collection("riders")
      .where("account_status", "==", "approved")
      .get();

    let paid = 0;
    for (const doc of ridersSnap.docs) {
      const r = doc.data();
      const balance = Number(r.wallet_balance || 0);
      const payout = balance - FLOOR;
      if (payout <= 0) continue;

      // Most recent bank details this rider used (from their withdrawals).
      const wSnap = await db
        .collection("withdrawal_requests")
        .where("rider_id", "==", doc.id)
        .orderBy("created_at", "desc")
        .limit(20)
        .get();
      const bankDoc = wSnap.docs.find(
        (d) => (d.data().bank_account || "") !== ""
      );
      if (!bankDoc) continue; // no bank on file — skip until they withdraw once
      const bank = bankDoc.data();

      const batch = db.batch();
      batch.set(db.collection("withdrawal_requests").doc(), {
        rider_id: doc.id,
        amount: payout,
        bank_account: bank.bank_account,
        bank_ifsc: bank.bank_ifsc,
        account_holder_name: bank.account_holder_name || null,
        bank_name: bank.bank_name || null,
        status: "pending",
        is_auto: true,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.update(doc.ref, { wallet_balance: FLOOR });
      batch.set(db.collection("wallet_transactions").doc(), {
        rider_id: doc.id,
        type: "debit",
        amount: payout,
        description: "Daily auto-payout to bank (8:00 AM)",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      await batch.commit();
      paid++;
    }

    logger.info(`Daily auto-payout complete: ${paid} rider(s) paid out.`);
  }
);
