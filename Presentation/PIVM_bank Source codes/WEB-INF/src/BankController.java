import java.io.IOException;
import java.io.PrintWriter;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.sql.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/**
 * PIVM Bank - front controller.
 *  POST actions : login, logout, create, approve, delete, transact
 *  GET  actions : lookup  (JSON recipient lookup used by the transfer page)
 */
@WebServlet("/BankController")
public class BankController extends HttpServlet {
    // If your MySQL is on 3306, change 3307 back to 3306 here.
    private static final String DB_URL = "jdbc:mysql://localhost:3307/woxsen_bank_db";
    private static final String USER = "root";
    private static final String PASS = "";

    static {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
    }

    /* ---------- helpers ---------- */

    private static void go(HttpServletResponse res, String page, String msg, boolean ok) throws IOException {
        String sep = page.contains("?") ? "&" : "?";
        res.sendRedirect(page + sep + "msg=" + URLEncoder.encode(msg, "UTF-8") + "&t=" + (ok ? "ok" : "err"));
    }

    private static boolean isAdmin(HttpSession s) {
        return "admin".equals(s.getAttribute("role"));
    }

    private static boolean isCustomer(HttpSession s) {
        return "customer".equals(s.getAttribute("role")) && s.getAttribute("account_no") != null;
    }

    /** "Pareddy Ishanth Reddy" -> "Pareddy I. R." (beneficiary masking, like real banking apps) */
    private static String maskName(String full) {
        if (full == null || full.trim().isEmpty()) return "";
        String[] p = full.trim().split("\\s+");
        StringBuilder sb = new StringBuilder(p[0]);
        for (int i = 1; i < p.length; i++) sb.append(' ').append(p[i].charAt(0)).append('.');
        return sb.toString();
    }

    private static String json(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    /* ---------- GET : recipient lookup ---------- */

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        if (!"lookup".equals(request.getParameter("action")) || !isCustomer(session)) {
            response.sendRedirect("index.jsp");
            return;
        }
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        PrintWriter out = response.getWriter();
        String username = request.getParameter("username");
        int me = (Integer) session.getAttribute("account_no");

        if (username == null || username.trim().isEmpty()) {
            out.print("{\"found\":false}");
            return;
        }
        try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASS);
             PreparedStatement ps = conn.prepareStatement(
                     "SELECT account_no, customer_name FROM Accounts WHERE username = ? AND status = 'Active'")) {
            ps.setString(1, username.trim());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    int acc = rs.getInt("account_no");
                    out.print("{\"found\":true,\"self\":" + (acc == me)
                            + ",\"name\":\"" + json(maskName(rs.getString("customer_name"))) + "\""
                            + ",\"account\":\"" + String.format("%08d", acc) + "\"}");
                } else {
                    out.print("{\"found\":false}");
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
            out.print("{\"found\":false,\"error\":true}");
        }
    }

    /* ---------- POST ---------- */

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        HttpSession session = request.getSession();
        if (action == null) { response.sendRedirect("index.jsp"); return; }

        try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASS)) {

            // 1. Authentication
            if ("login".equals(action)) {
                String username = request.getParameter("username");
                String pin = request.getParameter("pin");
                boolean adminPortal = "admin".equals(request.getParameter("type"));
                String back = "login.jsp?type=" + (adminPortal ? "admin" : "customer");

                if (username == null || pin == null) { go(response, back, "Please enter your credentials.", false); return; }
                username = username.trim();

                if ("admin".equals(username) && "admin123".equals(pin)) {
                    if (!adminPortal) {
                        go(response, "login.jsp?type=admin", "Administrator credentials detected. Please use the Administration Login.", false);
                        return;
                    }
                    session.setAttribute("role", "admin");
                    response.sendRedirect("index.jsp");
                    return;
                }
                if (adminPortal) {
                    go(response, back, "Invalid administrator credentials.", false);
                    return;
                }

                try (PreparedStatement ps = conn.prepareStatement("SELECT * FROM Accounts WHERE username = ? AND pin = ?")) {
                    ps.setString(1, username);
                    ps.setString(2, pin);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            if ("Pending".equals(rs.getString("status"))) {
                                go(response, back, "Your application is still under review by administration.", false);
                            } else {
                                session.setAttribute("role", "customer");
                                session.setAttribute("account_no", rs.getInt("account_no"));
                                session.setAttribute("customer_name", rs.getString("customer_name"));
                                session.setAttribute("username", rs.getString("username"));
                                response.sendRedirect("index.jsp");
                            }
                        } else {
                            go(response, back, "Invalid credentials provided.", false);
                        }
                    }
                }
            }
            // 2. Logout
            else if ("logout".equals(action)) {
                session.invalidate();
                go(response, "index.jsp", "You have been signed out securely.", true);
            }
            // 3. Create Account (status = Pending)
            else if ("create".equals(action)) {
                String name = request.getParameter("customer_name");
                String username = request.getParameter("username");
                String type = request.getParameter("account_type");
                String pin = request.getParameter("pin");
                BigDecimal bal;
                try {
                    bal = new BigDecimal(request.getParameter("balance")).setScale(2, RoundingMode.HALF_UP);
                } catch (Exception e) {
                    go(response, "create.jsp", "Please enter a valid opening deposit.", false);
                    return;
                }
                if (name == null || name.trim().isEmpty() || username == null || type == null || pin == null) {
                    go(response, "create.jsp", "All fields are required.", false);
                    return;
                }
                name = name.trim();
                username = username.trim();
                if (!username.matches("[A-Za-z0-9_.]{3,20}") || "admin".equalsIgnoreCase(username)) {
                    go(response, "create.jsp", "Username must be 3-20 characters (letters, digits, _ or .).", false);
                    return;
                }
                if (!pin.matches("\\d{4}")) {
                    go(response, "create.jsp", "PIN must be exactly 4 digits.", false);
                    return;
                }
                if (!"Savings".equals(type) && !"Current".equals(type)) type = "Savings";
                if (bal.compareTo(new BigDecimal("500")) < 0) {
                    go(response, "create.jsp", "Minimum opening deposit is \u20B9500.", false);
                    return;
                }
                try (PreparedStatement chk = conn.prepareStatement("SELECT 1 FROM Accounts WHERE username = ?")) {
                    chk.setString(1, username);
                    try (ResultSet rs = chk.executeQuery()) {
                        if (rs.next()) { go(response, "create.jsp", "Username is already taken. Please choose another.", false); return; }
                    }
                }
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO Accounts (username, pin, customer_name, account_type, balance, status) VALUES (?, ?, ?, ?, ?, 'Pending')")) {
                    ps.setString(1, username);
                    ps.setString(2, pin);
                    ps.setString(3, name);
                    ps.setString(4, type);
                    ps.setBigDecimal(5, bal);
                    ps.executeUpdate();
                    go(response, "index.jsp", "Application submitted successfully. Pending administrative approval.", true);
                } catch (SQLIntegrityConstraintViolationException e) {
                    go(response, "create.jsp", "Username is already taken. Please choose another.", false);
                }
            }
            // 4. Admin approve
            else if ("approve".equals(action)) {
                if (!isAdmin(session)) { go(response, "login.jsp?type=admin", "Administrator access required.", false); return; }
                int accNo = Integer.parseInt(request.getParameter("account_no"));
                try (PreparedStatement ps = conn.prepareStatement("UPDATE Accounts SET status = 'Active' WHERE account_no = ?")) {
                    ps.setInt(1, accNo);
                    ps.executeUpdate();
                }
                go(response, "index.jsp", "Account approved and activated.", true);
            }
            // 5. Admin reject / close
            else if ("delete".equals(action)) {
                if (!isAdmin(session)) { go(response, "login.jsp?type=admin", "Administrator access required.", false); return; }
                int accNo = Integer.parseInt(request.getParameter("account_no"));
                try (PreparedStatement ps = conn.prepareStatement("DELETE FROM Accounts WHERE account_no = ?")) {
                    ps.setInt(1, accNo);
                    ps.executeUpdate();
                    go(response, "index.jsp", "Account record removed.", true);
                } catch (SQLIntegrityConstraintViolationException e) {
                    go(response, "index.jsp", "This account has transaction history and cannot be deleted.", false);
                }
            }
            // 6. Transactions (deposit / withdraw / transfer) - atomic
            else if ("transact".equals(action)) {
                if (!isCustomer(session)) { go(response, "login.jsp?type=customer", "Please sign in to continue.", false); return; }
                // sender comes from the SESSION, never from a form field
                int sender = (Integer) session.getAttribute("account_no");
                String[] r = processTransaction(conn, sender,
                        request.getParameter("txn_type"),
                        request.getParameter("amount"),
                        request.getParameter("target_username"),
                        request.getParameter("pin"));
                // r[0] = "ok"/"err", r[1] = message
                boolean ok = "ok".equals(r[0]);
                go(response, ok ? "index.jsp" : "transact.jsp", r[1], ok);
            }
        } catch (SQLException e) {
            e.printStackTrace();
            go(response, "index.jsp", "System Error: Database exception - " + e.getMessage(), false);
        } catch (NumberFormatException e) {
            go(response, "index.jsp", "Invalid input received.", false);
        }
    }

    /**
     * Runs one deposit / withdrawal / transfer as a single DB transaction.
     * Rows are locked with SELECT ... FOR UPDATE (in account_no order, so two
     * simultaneous transfers can never deadlock) and everything is rolled back on any failure.
     */
    private String[] processTransaction(Connection conn, int sender, String type, String amountStr,
                                        String targetUsername, String pin) throws SQLException {
        BigDecimal amount;
        try {
            amount = new BigDecimal(amountStr).setScale(2, RoundingMode.HALF_UP);
        } catch (Exception e) {
            return new String[]{"err", "Please enter a valid amount."};
        }
        if (amount.signum() <= 0) return new String[]{"err", "Amount must be greater than zero."};
        if (type == null || !(type.equals("Deposit") || type.equals("Withdraw") || type.equals("Transfer")))
            return new String[]{"err", "Unknown transaction type."};
        if (pin == null || pin.isEmpty()) return new String[]{"err", "Enter your PIN to authorise this transaction."};

        // Resolve the recipient (transfers only)
        int target = sender;
        if (type.equals("Transfer")) {
            if (targetUsername == null || targetUsername.trim().isEmpty())
                return new String[]{"err", "Please enter the recipient's username."};
            try (PreparedStatement ps = conn.prepareStatement("SELECT account_no, status FROM Accounts WHERE username = ?")) {
                ps.setString(1, targetUsername.trim());
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next() || !"Active".equals(rs.getString("status")))
                        return new String[]{"err", "Recipient not found or account is not active."};
                    target = rs.getInt("account_no");
                }
            }
            if (target == sender) return new String[]{"err", "You cannot transfer to your own account."};
        }

        conn.setAutoCommit(false);
        try {
            BigDecimal senderBal = null;
            String senderPin = null, senderStatus = null;
            try (PreparedStatement lock = conn.prepareStatement(
                    "SELECT account_no, pin, balance, status FROM Accounts WHERE account_no IN (?, ?) ORDER BY account_no FOR UPDATE")) {
                lock.setInt(1, sender);
                lock.setInt(2, target);
                try (ResultSet rs = lock.executeQuery()) {
                    while (rs.next()) {
                        if (rs.getInt("account_no") == sender) {
                            senderBal = rs.getBigDecimal("balance");
                            senderPin = rs.getString("pin");
                            senderStatus = rs.getString("status");
                        }
                    }
                }
            }
            if (senderBal == null || !"Active".equals(senderStatus)) {
                conn.rollback();
                return new String[]{"err", "Your account is not active."};
            }
            if (!pin.equals(senderPin)) {
                conn.rollback();
                return new String[]{"err", "Incorrect PIN. Transaction cancelled."};
            }

            String done;
            if (type.equals("Deposit")) {
                updateBalance(conn, sender, amount);
                log(conn, sender, "Deposit", amount, null);
                done = "Deposit of \u20B9" + amount.toPlainString() + " completed.";
            } else {
                if (senderBal.compareTo(amount) < 0) {
                    conn.rollback();
                    return new String[]{"err", "Insufficient funds for this " + (type.equals("Withdraw") ? "withdrawal." : "transfer.")};
                }
                updateBalance(conn, sender, amount.negate());
                if (type.equals("Withdraw")) {
                    log(conn, sender, "Withdraw", amount, null);
                    done = "Withdrawal of \u20B9" + amount.toPlainString() + " completed.";
                } else {
                    updateBalance(conn, target, amount);
                    log(conn, sender, "Transfer_Out", amount, target);
                    log(conn, target, "Transfer_In", amount, sender);
                    done = "\u20B9" + amount.toPlainString() + " transferred to " + targetUsername.trim() + " successfully.";
                }
            }
            conn.commit();
            return new String[]{"ok", done};
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            conn.setAutoCommit(true);
        }
    }

    private static void updateBalance(Connection conn, int acc, BigDecimal delta) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement("UPDATE Accounts SET balance = balance + ? WHERE account_no = ?")) {
            ps.setBigDecimal(1, delta);
            ps.setInt(2, acc);
            ps.executeUpdate();
        }
    }

    private static void log(Connection conn, int acc, String type, BigDecimal amount, Integer related) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO Transactions (account_no, txn_type, amount, related_account) VALUES (?, ?, ?, ?)")) {
            ps.setInt(1, acc);
            ps.setString(2, type);
            ps.setBigDecimal(3, amount);
            if (related == null) ps.setNull(4, Types.INTEGER); else ps.setInt(4, related);
            ps.executeUpdate();
        }
    }
}
