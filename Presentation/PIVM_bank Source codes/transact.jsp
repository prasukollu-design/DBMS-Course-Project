<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*, java.util.*, java.math.BigDecimal" %>
<%@ include file="header.jsp" %>
<%
    if (!"customer".equals(role)) { response.sendRedirect("index.jsp"); return; }

    int accountNo = (Integer) session.getAttribute("account_no");
    BigDecimal balance = BigDecimal.ZERO;
    String acctType = "";
    List<String[]> recents = new ArrayList<>();   // {username, name}

    try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
        try (PreparedStatement ps = conn.prepareStatement("SELECT balance, account_type FROM Accounts WHERE account_no = ?")) {
            ps.setInt(1, accountNo);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) { balance = rs.getBigDecimal("balance"); acctType = rs.getString("account_type"); }
            }
        }
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT a.username, a.customer_name FROM Transactions t JOIN Accounts a ON a.account_no = t.related_account " +
                "WHERE t.account_no = ? AND t.txn_type = 'Transfer_Out' AND a.status = 'Active' " +
                "GROUP BY a.username, a.customer_name ORDER BY MAX(t.txn_date) DESC LIMIT 4")) {
            ps.setInt(1, accountNo);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) recents.add(new String[]{ rs.getString(1), rs.getString(2) });
            }
        }
    } catch (Exception e) { /* page still renders; server validates every transaction anyway */ }

    String mode = request.getParameter("mode");
    if (mode == null || !(mode.equals("deposit") || mode.equals("withdraw"))) mode = "transfer";
    String accStr = String.format("%08d", accountNo);
%>

<div class="page-head rise">
    <h2>Transfer &amp; Payments</h2>
    <p>Send money to another PIVM customer, or manage cash in your own account.</p>
</div>

<div class="grid-2">
    <div class="card rise" style="animation-delay:.1s">
        <div class="seg-wrap" id="segs">
            <button type="button" class="seg" data-mode="transfer">Send Money</button>
            <button type="button" class="seg" data-mode="deposit">Deposit</button>
            <button type="button" class="seg" data-mode="withdraw">Withdraw</button>
        </div>

        <form action="BankController" method="POST" id="txnForm" autocomplete="off">
            <input type="hidden" name="action" value="transact">
            <input type="hidden" name="txn_type" id="txnType" value="Transfer">

            <div id="recipientBlock">
                <div class="field">
                    <label class="lbl" for="targetUser">Recipient's username</label>
                    <input type="text" id="targetUser" name="target_username" placeholder="e.g. ishanth_r" maxlength="20" autocapitalize="off" spellcheck="false">
                    <div class="hint" id="lookupHint">Enter the username of the customer you want to pay.</div>
                    <% if (!recents.isEmpty()) { %>
                    <div class="chips">
                        <% for (String[] r : recents) { %>
                            <button type="button" class="chip" data-user="<%= esc(r[0]) %>">@<%= esc(r[0]) %></button>
                        <% } %>
                    </div>
                    <% } %>
                </div>
            </div>

            <div class="field">
                <label class="lbl" for="amount">Amount</label>
                <div class="input-prefix"><span>&#8377;</span><input type="number" id="amount" name="amount" step="0.01" min="1" required placeholder="0.00"></div>
                <div class="chips" id="quick">
                    <button type="button" class="chip" data-amt="500">&#8377;500</button>
                    <button type="button" class="chip" data-amt="1000">&#8377;1,000</button>
                    <button type="button" class="chip" data-amt="5000">&#8377;5,000</button>
                    <button type="button" class="chip" data-amt="10000">&#8377;10,000</button>
                </div>
                <div class="hint" id="amountHint"></div>
            </div>

            <div class="field">
                <label class="lbl" for="pin">Confirm with your PIN</label>
                <input type="password" id="pin" name="pin" required inputmode="numeric" maxlength="4" pattern="[0-9]{4}" placeholder="&bull;&bull;&bull;&bull;">
            </div>

            <button type="submit" class="btn" id="submitBtn" style="margin-top:6px;">Send Money <svg width="18" height="18"><use href="#i-arrow"/></svg></button>
        </form>
    </div>

    <div>
        <div class="card rise" style="animation-delay:.2s">
            <div class="card-title">Your account</div>
            <div class="balance-label">Available balance</div>
            <div class="balance-amount" style="font-size:40px;margin-bottom:14px;"><span>&#8377;</span><%= inr(balance.doubleValue()) %></div>
            <div class="summary-row"><span>Account</span><span class="mono"><%= accStr.substring(0, 4) %> <%= accStr.substring(4) %></span></div>
            <div class="summary-row"><span>Type</span><span><%= esc(acctType) %></span></div>
            <div class="summary-row"><span>Balance after this</span><span id="after">&mdash;</span></div>
        </div>
        <div class="note rise" style="animation-delay:.3s">
            <svg width="18" height="18"><use href="#i-shield"/></svg>
            <span>Every transaction is processed as a single atomic operation: the debit and the credit either both succeed or neither does.</span>
        </div>
    </div>
</div>

<script>
(function () {
    var balance = <%= balance.toPlainString() %>;
    var initialMode = "<%= mode %>";
    var modes = {
        transfer: { type: "Transfer", label: "Send Money" },
        deposit:  { type: "Deposit",  label: "Deposit Funds" },
        withdraw: { type: "Withdraw", label: "Withdraw Cash" }
    };
    var mode = initialMode;
    var lookup = "idle";   // idle | checking | ok | bad | self | unknown

    var $ = function (id) { return document.getElementById(id); };
    var segs = document.querySelectorAll(".seg");
    var recipient = $("recipientBlock"), target = $("targetUser"), hint = $("lookupHint");
    var amount = $("amount"), amountHint = $("amountHint"), after = $("after");
    var btn = $("submitBtn"), txnType = $("txnType"), form = $("txnForm");
    var timer = null;

    function fmt(n) { return "\u20B9" + n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }

    function setHint(text, cls) { hint.textContent = text; hint.className = "hint" + (cls ? " " + cls : ""); }

    function refresh() {
        var amt = parseFloat(amount.value);
        var valid = !isNaN(amt) && amt > 0;
        var debit = mode !== "deposit";
        var result = valid ? (debit ? balance - amt : balance + amt) : null;

        after.textContent = result === null ? "\u2014" : fmt(result);
        after.className = result !== null && result < 0 ? "neg" : "";

        var insufficient = valid && debit && amt > balance;
        amountHint.textContent = insufficient ? "This exceeds your available balance." : "";
        amountHint.className = "hint" + (insufficient ? " bad" : "");

        var recipientOk = mode !== "transfer" || lookup === "ok" || lookup === "unknown";
        btn.disabled = !(valid && !insufficient && recipientOk);
    }

    function setMode(m) {
        mode = m;
        txnType.value = modes[m].type;
        for (var i = 0; i < segs.length; i++) segs[i].classList.toggle("on", segs[i].getAttribute("data-mode") === m);
        recipient.style.display = m === "transfer" ? "block" : "none";
        target.required = (m === "transfer");
        btn.firstChild.nodeValue = modes[m].label + " ";
        refresh();
    }

    function doLookup() {
        var v = target.value.trim();
        if (!v) { lookup = "idle"; setHint("Enter the username of the customer you want to pay."); refresh(); return; }
        lookup = "checking"; setHint("Checking\u2026"); refresh();
        fetch("BankController?action=lookup&username=" + encodeURIComponent(v), { credentials: "same-origin" })
            .then(function (r) { return r.json(); })
            .then(function (d) {
                if (target.value.trim() !== v) return;   // stale response
                if (d.error) { lookup = "unknown"; setHint("Could not verify the recipient right now; it will be checked when you submit."); }
                else if (!d.found) { lookup = "bad"; setHint("No active customer found with that username.", "bad"); }
                else if (d.self) { lookup = "self"; setHint("That is your own account. Choose a different recipient.", "bad"); }
                else { lookup = "ok"; setHint("\u2713 " + d.name + "  \u00B7  A/C " + d.account, "ok"); }
                if (lookup === "self") lookup = "bad";
                refresh();
            })
            .catch(function () { lookup = "unknown"; setHint("Could not verify the recipient right now; it will be checked when you submit."); refresh(); });
    }

    for (var i = 0; i < segs.length; i++) {
        segs[i].addEventListener("click", function () { setMode(this.getAttribute("data-mode")); });
    }
    target.addEventListener("input", function () { lookup = "checking"; clearTimeout(timer); timer = setTimeout(doLookup, 350); refresh(); });
    amount.addEventListener("input", refresh);

    document.querySelectorAll("#quick .chip").forEach(function (c) {
        c.addEventListener("click", function () { amount.value = this.getAttribute("data-amt"); refresh(); });
    });
    document.querySelectorAll(".chips .chip[data-user]").forEach(function (c) {
        c.addEventListener("click", function () { target.value = this.getAttribute("data-user"); doLookup(); });
    });
    form.addEventListener("submit", function () { btn.disabled = true; });

    setMode(initialMode);
    lookup = "idle";
    refresh();
})();
</script>

<%@ include file="footer.jsp" %>
