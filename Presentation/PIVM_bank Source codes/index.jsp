<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*, java.util.*, java.text.SimpleDateFormat" %>
<%@ include file="header.jsp" %>

<% if (isLanding) { %>
<!-- ================= PUBLIC LANDING PAGE ================= -->
<div class="landing-top rise">
    <div class="brand">
        <span class="logo"><svg width="20" height="20"><use href="#i-bank"/></svg></span>
        <span class="brand-text">PIVM <em>Bank</em></span>
    </div>
    <span class="secure-pill"><svg width="15" height="15"><use href="#i-lock"/></svg>Secure banking portal</span>
</div>

<section class="hero">
    <span class="eyebrow rise" style="animation-delay:.05s">Retail &amp; Corporate Banking</span>
    <h1 class="rise" style="animation-delay:.15s">Welcome to <em>PIVM Bank</em></h1>
    <p class="lead rise" style="animation-delay:.25s">Excellence in wealth management and secure transactions. Open an account, manage your money and move it instantly &mdash; all in one place.</p>

    <div class="portal-grid">
        <a class="portal rise" style="animation-delay:.35s" href="login.jsp?type=customer">
            <div class="ico"><svg width="30" height="30"><use href="#i-user"/></svg></div>
            <h3>Client Portal</h3>
            <p>Access your accounts, review statements and send money to any PIVM customer in seconds.</p>
            <span class="go">Sign in <svg width="18" height="18"><use href="#i-arrow"/></svg></span>
        </a>
        <a class="portal rise" style="animation-delay:.45s" href="create.jsp">
            <div class="ico"><svg width="30" height="30"><use href="#i-userplus"/></svg></div>
            <h3>Account Opening</h3>
            <p>Apply for a new savings or current account. Approval is reviewed by our administration team.</p>
            <span class="go">Apply now <svg width="18" height="18"><use href="#i-arrow"/></svg></span>
        </a>
        <a class="portal rise" style="animation-delay:.55s" href="login.jsp?type=admin">
            <span class="tag">Staff only</span>
            <div class="ico"><svg width="30" height="30"><use href="#i-shield"/></svg></div>
            <h3>Administration Login</h3>
            <p>Review applications, approve new accounts and oversee the central ledger.</p>
            <span class="go">Administrator access <svg width="18" height="18"><use href="#i-arrow"/></svg></span>
        </a>
    </div>

    <div class="trust rise" style="animation-delay:.7s">
        <div><svg width="26" height="26"><use href="#i-lock"/></svg><span><b>Bank-grade security</b><small>PIN-authorised transactions and role-based access on every request.</small></span></div>
        <div><svg width="26" height="26"><use href="#i-bolt"/></svg><span><b>Instant transfers</b><small>Send money to any customer by username, settled in real time.</small></span></div>
        <div><svg width="26" height="26"><use href="#i-ledger"/></svg><span><b>Transparent ledger</b><small>Every credit and debit is recorded atomically in your statement.</small></span></div>
    </div>
</section>

<% } else if ("admin".equals(role)) {
    // ================= ADMIN DASHBOARD =================
    List<Object[]> pending = new ArrayList<>();   // {acc, username, name, type, balance}
    List<Object[]> active  = new ArrayList<>();   // {acc, username, name, type, balance}
    List<Object[]> recent  = new ArrayList<>();   // {ts, type, username, relUsername, amount}
    int pendingCount = 0, activeCount = 0, txnCount = 0;
    double totalHeld = 0;
    String dbError = null;
    SimpleDateFormat fmt = new SimpleDateFormat("dd MMM yyyy, hh:mm a");

    try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT * FROM Accounts ORDER BY account_no")) {
            while (rs.next()) {
                Object[] row = { rs.getInt("account_no"), rs.getString("username"), rs.getString("customer_name"),
                                 rs.getString("account_type"), rs.getDouble("balance") };
                if ("Pending".equals(rs.getString("status"))) { pending.add(row); pendingCount++; }
                else if ("Active".equals(rs.getString("status"))) { active.add(row); activeCount++; totalHeld += rs.getDouble("balance"); }
            }
        }
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM Transactions")) {
            if (rs.next()) txnCount = rs.getInt(1);
        }
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(
                "SELECT t.txn_date, t.txn_type, t.amount, a.username AS u, r.username AS ru " +
                "FROM Transactions t JOIN Accounts a ON a.account_no = t.account_no " +
                "LEFT JOIN Accounts r ON r.account_no = t.related_account " +
                "WHERE t.txn_type <> 'Transfer_In' ORDER BY t.txn_date DESC LIMIT 8")) {
            while (rs.next()) {
                recent.add(new Object[]{ rs.getTimestamp("txn_date"), rs.getString("txn_type"),
                                         rs.getString("u"), rs.getString("ru"), rs.getDouble("amount") });
            }
        }
    } catch (Exception e) { dbError = e.getMessage(); }
%>
<div class="page-head rise">
    <h2>Administration Dashboard</h2>
    <p>Review applications, manage accounts and monitor activity across the bank.</p>
</div>
<% if (dbError != null) { %>
    <div class="alert err"><svg width="20" height="20"><use href="#i-alert"/></svg><span>Database error: <%= esc(dbError) %></span></div>
<% } %>

<div class="stats rise" style="animation-delay:.1s">
    <div class="stat"><small>Pending applications</small><b><%= pendingCount %></b></div>
    <div class="stat"><small>Active accounts</small><b><%= activeCount %></b></div>
    <div class="stat"><small>Deposits held</small><b>&#8377;<%= inr(totalHeld) %></b></div>
    <div class="stat"><small>Transactions recorded</small><b><%= txnCount %></b></div>
</div>

<div class="card" id="approvals">
    <div class="card-title">Pending Account Approvals <small><%= pendingCount %> awaiting review</small></div>
    <div class="table-wrap">
    <table>
        <thead><tr><th>Username</th><th>Client Name</th><th>Type</th><th class="num">Initial Deposit</th><th style="text-align:center;">Actions</th></tr></thead>
        <tbody>
        <% for (Object[] p : pending) { %>
            <tr>
                <td>@<%= esc((String) p[1]) %></td>
                <td><%= esc((String) p[2]) %></td>
                <td><span class="pill gold"><%= esc((String) p[3]) %></span></td>
                <td class="num">&#8377;<%= inr((Double) p[4]) %></td>
                <td>
                    <div class="actions">
                        <form action="BankController" method="POST">
                            <input type="hidden" name="action" value="approve">
                            <input type="hidden" name="account_no" value="<%= p[0] %>">
                            <button type="submit" class="btn-sm btn-ok">Approve</button>
                        </form>
                        <form action="BankController" method="POST" onsubmit="return confirm('Reject and remove this application?');">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="account_no" value="<%= p[0] %>">
                            <button type="submit" class="btn-sm btn-danger">Reject</button>
                        </form>
                    </div>
                </td>
            </tr>
        <% } if (pending.isEmpty()) { %>
            <tr><td colspan="5" class="empty">No pending requests. You're all caught up.</td></tr>
        <% } %>
        </tbody>
    </table>
    </div>
</div>

<div class="card" id="ledger">
    <div class="card-title">Active Central Ledger <small><%= activeCount %> accounts</small></div>
    <div class="table-wrap">
    <table>
        <thead><tr><th>Account No</th><th>Username</th><th>Client Name</th><th>Type</th><th class="num">Balance</th><th style="text-align:center;">Action</th></tr></thead>
        <tbody>
        <% for (Object[] a : active) { %>
            <tr>
                <td class="mono"><%= String.format("%08d", (Integer) a[0]) %></td>
                <td>@<%= esc((String) a[1]) %></td>
                <td><%= esc((String) a[2]) %></td>
                <td><span class="pill"><%= esc((String) a[3]) %></span></td>
                <td class="num">&#8377;<%= inr((Double) a[4]) %></td>
                <td>
                    <div class="actions">
                        <form action="BankController" method="POST" onsubmit="return confirm('Close this account permanently?');">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="account_no" value="<%= a[0] %>">
                            <button type="submit" class="btn-sm btn-danger">Close Account</button>
                        </form>
                    </div>
                </td>
            </tr>
        <% } if (active.isEmpty()) { %>
            <tr><td colspan="6" class="empty">No active accounts yet.</td></tr>
        <% } %>
        </tbody>
    </table>
    </div>
</div>

<div class="card" id="activity">
    <div class="card-title">Recent Activity <small>latest 8 transactions</small></div>
    <div class="table-wrap">
    <table>
        <thead><tr><th>Date</th><th>Account</th><th>Activity</th><th class="num">Amount</th></tr></thead>
        <tbody>
        <% for (Object[] r : recent) {
            String rt = (String) r[1];
            String what = rt.equals("Deposit") ? "Deposit"
                        : rt.equals("Withdraw") ? "Withdrawal"
                        : "Transfer to @" + esc((String) r[3]);
        %>
            <tr>
                <td class="muted"><%= fmt.format((Timestamp) r[0]) %></td>
                <td>@<%= esc((String) r[2]) %></td>
                <td><%= what %></td>
                <td class="num"><%= inr((Double) r[4]) %></td>
            </tr>
        <% } if (recent.isEmpty()) { %>
            <tr><td colspan="4" class="empty">No transactions have been recorded yet.</td></tr>
        <% } %>
        </tbody>
    </table>
    </div>
</div>

<% } else if ("customer".equals(role)) {
    // ================= CUSTOMER OVERVIEW =================
    int accountNo = (Integer) session.getAttribute("account_no");
    double currentBalance = 0, credited = 0, debited = 0;
    int txnTotal = 0;
    String acctType = "";
    String dbError = null;
    List<Object[]> txns = new ArrayList<>();  // {ts, type, relUser, relName, relAcc, amount}
    SimpleDateFormat fmt = new SimpleDateFormat("dd MMM yyyy, hh:mm a");

    try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
        try (PreparedStatement ps = conn.prepareStatement("SELECT balance, account_type FROM Accounts WHERE account_no = ?")) {
            ps.setInt(1, accountNo);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) { currentBalance = rs.getDouble("balance"); acctType = rs.getString("account_type"); }
            }
        }
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT COALESCE(SUM(CASE WHEN txn_type IN ('Deposit','Transfer_In') THEN amount END),0) AS cr, " +
                "COALESCE(SUM(CASE WHEN txn_type IN ('Withdraw','Transfer_Out') THEN amount END),0) AS dr, COUNT(*) AS n " +
                "FROM Transactions WHERE account_no = ?")) {
            ps.setInt(1, accountNo);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) { credited = rs.getDouble("cr"); debited = rs.getDouble("dr"); txnTotal = rs.getInt("n"); }
            }
        }
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT t.txn_date, t.txn_type, t.amount, t.related_account, a.username AS rel_user, a.customer_name AS rel_name " +
                "FROM Transactions t LEFT JOIN Accounts a ON a.account_no = t.related_account " +
                "WHERE t.account_no = ? ORDER BY t.txn_date DESC")) {
            ps.setInt(1, accountNo);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    txns.add(new Object[]{ rs.getTimestamp("txn_date"), rs.getString("txn_type"),
                                           rs.getString("rel_user"), rs.getString("rel_name"),
                                           rs.getInt("related_account"), rs.getDouble("amount") });
                }
            }
        }
    } catch (Exception e) { dbError = e.getMessage(); }
    String accStr = String.format("%08d", accountNo);
%>
<div class="page-head rise">
    <h2>Welcome back, <%= esc(((String) session.getAttribute("customer_name")).split("\\s+")[0]) %></h2>
    <p>Here is a summary of your account.</p>
</div>
<% if (dbError != null) { %>
    <div class="alert err"><svg width="20" height="20"><use href="#i-alert"/></svg><span>Database error: <%= esc(dbError) %></span></div>
<% } %>

<div class="card balance-card rise" style="animation-delay:.1s">
    <div class="balance-top">
        <span class="balance-label">Available balance</span>
        <span><span class="pill gold"><%= esc(acctType) %> account</span> <span class="pill mono">A/C <%= accStr.substring(0, 4) %> <%= accStr.substring(4) %></span></span>
    </div>
    <div class="balance-amount"><span>&#8377;</span><%= inr(currentBalance) %></div>
    <div class="btn-row">
        <a class="btn inline" href="transact.jsp?mode=transfer"><svg width="18" height="18"><use href="#i-swap"/></svg>Send Money</a>
        <a class="btn-ghost" href="transact.jsp?mode=deposit">Deposit</a>
        <a class="btn-ghost" href="transact.jsp?mode=withdraw">Withdraw</a>
    </div>
</div>

<div class="stats rise" style="animation-delay:.2s">
    <div class="stat"><small>Total credited</small><b class="pos">+&#8377;<%= inr(credited) %></b></div>
    <div class="stat"><small>Total debited</small><b class="neg">&minus;&#8377;<%= inr(debited) %></b></div>
    <div class="stat"><small>Transactions</small><b><%= txnTotal %></b></div>
</div>

<div class="card rise" id="history" style="animation-delay:.3s">
    <div class="card-title">Transaction History <small>most recent first</small></div>
    <div class="table-wrap">
    <table>
        <thead><tr><th>Date</th><th>Description</th><th>Type</th><th class="num">Amount</th></tr></thead>
        <tbody>
        <% for (Object[] t : txns) {
            String type = (String) t[1];
            boolean credit = type.equals("Deposit") || type.equals("Transfer_In");
            String who = t[2] != null ? esc((String) t[3]) + " (@" + esc((String) t[2]) + ")"
                       : ((Integer) t[4] != 0 ? "A/C " + String.format("%08d", (Integer) t[4]) : "");
            String desc = type.equals("Deposit") ? "Deposit to account"
                        : type.equals("Withdraw") ? "Withdrawal from account"
                        : type.equals("Transfer_Out") ? "Transfer to " + who
                        : "Received from " + who;
        %>
            <tr>
                <td class="muted"><%= fmt.format((Timestamp) t[0]) %></td>
                <td><%= desc %></td>
                <td><span class="pill <%= credit ? "in" : "out" %>"><%= esc(type.replace("_", " ")) %></span></td>
                <td class="num <%= credit ? "pos" : "neg" %>"><%= credit ? "+" : "&minus;" %>&#8377;<%= inr((Double) t[5]) %></td>
            </tr>
        <% } if (txns.isEmpty()) { %>
            <tr><td colspan="4" class="empty">No transactions yet. Make a deposit or send money to get started.</td></tr>
        <% } %>
        </tbody>
    </table>
    </div>
</div>
<% } %>

<%@ include file="footer.jsp" %>
