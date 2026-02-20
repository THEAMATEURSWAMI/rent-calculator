/**
 * Firebase Cloud Functions — Plaid backend for Rent Calculator
 *
 * SETUP
 * -----
 * 1. npm install -g firebase-tools
 * 2. firebase login
 * 3. cd functions && npm install
 * 4. Set Plaid credentials (sandbox for testing, production when ready):
 *      firebase functions:config:set \
 *        plaid.client_id="YOUR_CLIENT_ID" \
 *        plaid.secret="YOUR_SANDBOX_SECRET" \
 *        plaid.env="sandbox"
 * 5. firebase deploy --only functions
 *
 * PLAID ENVIRONMENTS
 * ------------------
 *   sandbox    — fake bank logins, free, instant approval
 *   development — real banks, 100 live items free
 *   production  — real banks, paid
 */

const functions = require("firebase-functions");
const admin     = require("firebase-admin");
const cors      = require("cors")({ origin: true });
const {
  Configuration,
  PlaidApi,
  PlaidEnvironments,
  Products,
  CountryCode,
} = require("plaid");

admin.initializeApp();
const db = admin.firestore();

// ── Plaid client ─────────────────────────────────────────────────────────────
function getPlaidClient() {
  const cfg   = functions.config().plaid || {};
  const env   = (cfg.env || "sandbox").toLowerCase();
  const envUrl = PlaidEnvironments[env] || PlaidEnvironments.sandbox;

  const config = new Configuration({
    basePath: envUrl,
    baseOptions: {
      headers: {
        "PLAID-CLIENT-ID": cfg.client_id || "",
        "PLAID-SECRET":    cfg.secret    || "",
      },
    },
  });
  return new PlaidApi(config);
}

// ── CORS wrapper ─────────────────────────────────────────────────────────────
function withCors(fn) {
  return functions.https.onRequest((req, res) => {
    cors(req, res, () => fn(req, res));
  });
}

// ── /ping — health check ─────────────────────────────────────────────────────
exports.ping = withCors((req, res) => {
  res.json({ status: "ok", ts: Date.now() });
});

// ── /createLinkToken ─────────────────────────────────────────────────────────
exports.createLinkToken = withCors(async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const plaid    = getPlaidClient();
    const response = await plaid.linkTokenCreate({
      user:          { client_user_id: userId },
      client_name:   "Rent Calculator",
      products:      [Products.Transactions],
      country_codes: [CountryCode.Us],
      language:      "en",
    });

    res.json({ link_token: response.data.link_token });
  } catch (err) {
    console.error("createLinkToken error:", err?.response?.data || err);
    res.status(500).json({ error: err.message || "Internal error" });
  }
});

// ── /exchangePublicToken ──────────────────────────────────────────────────────
exports.exchangePublicToken = withCors(async (req, res) => {
  try {
    const { publicToken, userId } = req.body;
    if (!publicToken || !userId) {
      return res.status(400).json({ error: "publicToken and userId required" });
    }

    const plaid    = getPlaidClient();

    // Exchange token
    const exchangeRes = await plaid.itemPublicTokenExchange({
      public_token: publicToken,
    });
    const { access_token, item_id } = exchangeRes.data;

    // Get institution info
    const itemRes  = await plaid.itemGet({ access_token });
    const instId   = itemRes.data.item.institution_id;
    let   instName = "Your Bank";
    if (instId) {
      const instRes = await plaid.institutionsGetById({
        institution_id: instId,
        country_codes:  [CountryCode.Us],
      });
      instName = instRes.data.institution.name || instName;
    }

    // Get accounts
    const accountsRes = await plaid.accountsGet({ access_token });
    const accounts    = accountsRes.data.accounts.map((a) => ({
      account_id:       a.account_id,
      name:             a.name,
      type:             a.type,
      subtype:          a.subtype,
      mask:             a.mask,
      institution_name: instName,
      balances: {
        available: a.balances.available,
        current:   a.balances.current,
      },
    }));

    // Store access token securely (admin-only collection, no client rules)
    await db
      .collection("plaid_tokens")
      .doc(userId)
      .set(
        {
          [item_id]: {
            access_token,
            item_id,
            institution_id:   instId || "",
            institution_name: instName,
            created_at:       admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );

    res.json({
      institution_id:   instId || "",
      institution_name: instName,
      accounts,
    });
  } catch (err) {
    console.error("exchangePublicToken error:", err?.response?.data || err);
    res.status(500).json({ error: err.message || "Internal error" });
  }
});

// ── /getAccounts ──────────────────────────────────────────────────────────────
exports.getAccounts = withCors(async (req, res) => {
  try {
    const userId = req.query.userId;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const plaid   = getPlaidClient();
    const tokDoc  = await db.collection("plaid_tokens").doc(userId).get();
    if (!tokDoc.exists) {
      return res.json({ accounts: [] });
    }

    const tokens   = tokDoc.data();
    const allAccts = [];

    for (const item of Object.values(tokens)) {
      try {
        const r   = await plaid.accountsGet({ access_token: item.access_token });
        const mapped = r.data.accounts.map((a) => ({
          account_id:       a.account_id,
          name:             a.name,
          type:             a.type,
          subtype:          a.subtype,
          mask:             a.mask,
          institution_name: item.institution_name,
          balances: {
            available: a.balances.available,
            current:   a.balances.current,
          },
        }));
        allAccts.push(...mapped);
      } catch (itemErr) {
        console.warn("Could not fetch accounts for item:", itemErr.message);
      }
    }

    res.json({ accounts: allAccts });
  } catch (err) {
    console.error("getAccounts error:", err);
    res.status(500).json({ error: err.message || "Internal error" });
  }
});

// ── /syncTransactions ─────────────────────────────────────────────────────────
exports.syncTransactions = withCors(async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const plaid  = getPlaidClient();
    const tokDoc = await db.collection("plaid_tokens").doc(userId).get();
    if (!tokDoc.exists) {
      return res.status(404).json({ error: "No bank connection found" });
    }

    const tokens   = tokDoc.data();
    let   synced   = 0;
    const batch    = db.batch();

    for (const item of Object.values(tokens)) {
      // Use transactions/sync for incremental updates
      let cursor = item.cursor || "";
      let hasMore = true;
      const added = [];

      while (hasMore) {
        const syncRes = await plaid.transactionsSync({
          access_token: item.access_token,
          cursor,
        });
        added.push(...syncRes.data.added);
        cursor  = syncRes.data.next_cursor;
        hasMore = syncRes.data.has_more;
      }

      // Save cursor for next sync
      await db
        .collection("plaid_tokens")
        .doc(userId)
        .update({ [`${item.item_id}.cursor`]: cursor });

      // Write new transactions as expenses
      for (const txn of added) {
        if (txn.amount <= 0) continue; // skip credits / refunds
        const ref = db.collection("expenses").doc();
        batch.set(ref, {
          userId,
          name:        txn.name,
          amount:      txn.amount,
          category:    txn.personal_finance_category?.primary || "Other",
          date:        admin.firestore.Timestamp.fromDate(new Date(txn.date)),
          description: `Plaid sync — ${txn.merchant_name || txn.name}`,
          fromPlaid:   true,
          plaidTxnId:  txn.transaction_id,
          createdAt:   admin.firestore.FieldValue.serverTimestamp(),
        });
        synced++;
      }
    }

    await batch.commit();
    res.json({ synced });
  } catch (err) {
    console.error("syncTransactions error:", err?.response?.data || err);
    res.status(500).json({ error: err.message || "Internal error" });
  }
});

// ── /disconnect ───────────────────────────────────────────────────────────────
exports.disconnect = withCors(async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const plaid  = getPlaidClient();
    const tokDoc = await db.collection("plaid_tokens").doc(userId).get();

    if (tokDoc.exists) {
      // Remove each Plaid item
      for (const item of Object.values(tokDoc.data())) {
        try {
          await plaid.itemRemove({ access_token: item.access_token });
        } catch (_) {
          // best-effort
        }
      }
      await db.collection("plaid_tokens").doc(userId).delete();
    }

    res.json({ success: true });
  } catch (err) {
    console.error("disconnect error:", err);
    res.status(500).json({ error: err.message || "Internal error" });
  }
});
