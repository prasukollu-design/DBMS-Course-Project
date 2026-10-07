<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%!
    /* ---- shared helpers (available on every page that includes header.jsp) ---- */
    static String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }
    /** Indian digit grouping, e.g. 1234567.5 -> 12,34,567.50 (independent of JVM locale data) */
    static String inr(double d) {
        String s = String.format(java.util.Locale.US, "%.2f", Math.abs(d));
        String ip = s.substring(0, s.indexOf('.')), fp = s.substring(s.indexOf('.'));
        if (ip.length() > 3) {
            String head = ip.substring(0, ip.length() - 3), tail = ip.substring(ip.length() - 3);
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < head.length(); i++) {
                if (i > 0 && (head.length() - i) % 2 == 0) sb.append(',');
                sb.append(head.charAt(i));
            }
            ip = sb + "," + tail;
        }
        return (d < 0 ? "-" : "") + ip + fp;
    }
    static String act(boolean b) { return b ? " active" : ""; }
%>
<%
    // ---- Database settings used by every JSP page (BankController.java has its own copy) ----
    // If your MySQL is on 3306, change 3307 back to 3306 here AND in BankController.java.
    final String DB_URL  = "jdbc:mysql://localhost:3307/woxsen_bank_db";
    final String DB_USER = "root";
    final String DB_PASS = "";

    String role = (String) session.getAttribute("role");
    String uri = request.getRequestURI();
    String pageName = uri.substring(uri.lastIndexOf('/') + 1);
    if (pageName.isEmpty()) pageName = "index.jsp";

    boolean isLanding    = (role == null && pageName.equals("index.jsp"));
    boolean isAuthPage   = pageName.equals("login.jsp") || pageName.equals("create.jsp");
    boolean isPublicPage = pageName.equals("index.jsp") || isAuthPage;

    // Guests may only see the landing page, login and account opening.
    if (role == null && !isPublicPage) {
        response.sendRedirect("login.jsp?type=customer&msg=Please+sign+in+to+continue.&t=err");
        return;
    }
    // Signed-in users have no reason to see login / account opening again.
    if (role != null && isAuthPage) {
        response.sendRedirect("index.jsp");
        return;
    }

    String custName = (String) session.getAttribute("customer_name");
    Object custAccObj = session.getAttribute("account_no");
    String navType = "admin".equals(request.getParameter("type")) ? "admin" : "customer";
    String navName = "admin".equals(role) ? "Administrator" : (custName == null ? "" : custName);
    String navInitial = navName.isEmpty() ? "?" : navName.substring(0, 1).toUpperCase();
    String navSub = "admin".equals(role) ? "Bank staff"
            : (custAccObj == null ? "" : "A/C " + String.format("%08d", (Integer) custAccObj));
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>PIVM Bank</title>
    <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='8' fill='%23d9b86c'/%3E%3Cpath d='M16 7l9 6H7zM9 15v7M14 15v7M18 15v7M23 15v7M6 25h20' stroke='%231a1405' stroke-width='2' fill='none'/%3E%3C/svg%3E">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Playfair+Display:ital,wght@0,500;0,600;1,500&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #070d1f; --bg2: #0c1a33;
            --ink: #eef2f9; --muted: #9db0cc; --faint: #6f84a6;
            --gold: #d9b86c; --gold2: #f0d9a0; --gold-deep: #b8924a;
            --glass: rgba(255,255,255,.055); --glass-strong: rgba(255,255,255,.09);
            --line: rgba(255,255,255,.12);
            --ok: #4fd1a1; --err: #ff7a85;
            --radius: 20px;
            --serif: 'Playfair Display', Georgia, 'Times New Roman', serif;
            --sans: 'Inter', 'Segoe UI', system-ui, -apple-system, Roboto, Arial, sans-serif;
        }
        * { box-sizing: border-box; }
        html { scroll-behavior: smooth; }
        body {
            margin: 0; min-height: 100vh; display: flex; flex-direction: column;
            font-family: var(--sans); color: var(--ink); line-height: 1.55;
            -webkit-font-smoothing: antialiased;
            background:
                radial-gradient(1200px 700px at 12% -10%, #16305c 0%, transparent 60%),
                radial-gradient(900px 600px at 100% 8%, #0f3b4a 0%, transparent 55%),
                linear-gradient(180deg, var(--bg2), var(--bg));
            background-attachment: fixed;
        }
        a { color: var(--gold2); }

        /* ---------- ambient background ---------- */
        .orb { position: fixed; border-radius: 50%; filter: blur(90px); z-index: 0; pointer-events: none;
               animation: drift 24s ease-in-out infinite alternate; }
        .o1 { width: 460px; height: 460px; background: #c9a24d; top: -150px; right: -110px; opacity: .22; }
        .o2 { width: 520px; height: 520px; background: #2f6bff; bottom: -220px; left: -170px; opacity: .24; animation-delay: -8s; }
        .o3 { width: 340px; height: 340px; background: #14b8a6; top: 46%; left: 58%; opacity: .11; animation-delay: -14s; }
        @keyframes drift { to { transform: translate3d(40px, -30px, 0) scale(1.08); } }
        .dots { position: fixed; inset: 0; z-index: 0; pointer-events: none;
                background-image: radial-gradient(rgba(255,255,255,.055) 1px, transparent 1px);
                background-size: 30px 30px;
                -webkit-mask-image: linear-gradient(180deg, #000, transparent 85%);
                mask-image: linear-gradient(180deg, #000, transparent 85%); }

        /* ---------- brand + navbar ---------- */
        .brand { display: flex; align-items: center; gap: 12px; text-decoration: none; color: var(--ink); }
        .logo { width: 38px; height: 38px; border-radius: 11px; display: grid; place-items: center; color: #1a1405;
                background: linear-gradient(135deg, var(--gold2), var(--gold) 55%, var(--gold-deep));
                box-shadow: 0 8px 20px -8px rgba(217,184,108,.7); }
        .brand-text { font-family: var(--serif); font-size: 24px; letter-spacing: .02em; }
        .brand-text em { font-style: italic; color: var(--gold2); }
        .navbar { position: sticky; top: 0; z-index: 30;
                  background: rgba(8,15,34,.55); border-bottom: 1px solid var(--line);
                  -webkit-backdrop-filter: blur(16px) saturate(140%); backdrop-filter: blur(16px) saturate(140%); }
        .nav-inner { max-width: 1180px; margin: 0 auto; padding: 12px 24px; display: flex; align-items: center;
                     justify-content: space-between; gap: 16px; flex-wrap: wrap; }
        .nav-links { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
        .nav-links a { padding: 8px 15px; border-radius: 999px; color: var(--muted); text-decoration: none;
                       font-size: 14px; font-weight: 500; transition: .25s; }
        .nav-links a:hover { color: var(--ink); background: var(--glass-strong); }
        .nav-links a.active { color: var(--gold2); background: rgba(217,184,108,.12); }
        .nav-right { display: flex; align-items: center; gap: 14px; }
        .user-chip { display: flex; align-items: center; gap: 10px; }
        .avatar { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; font-weight: 600;
                  color: var(--gold2); background: rgba(217,184,108,.12); border: 1px solid rgba(217,184,108,.4); }
        .who { display: flex; flex-direction: column; line-height: 1.2; }
        .who b { font-size: 14px; font-weight: 500; }
        .who small { font-size: 11.5px; color: var(--faint); letter-spacing: .06em; }
        .btn-signout { background: transparent; color: var(--muted); border: 1px solid var(--line); border-radius: 999px;
                       padding: 8px 16px; font: inherit; font-size: 13px; cursor: pointer; transition: .25s; }
        .btn-signout:hover { color: var(--ink); border-color: rgba(255,255,255,.35); background: var(--glass); }

        /* ---------- layout ---------- */
        .container { position: relative; z-index: 1; flex: 1; width: 100%; max-width: 1180px; margin: 0 auto; padding: 36px 24px 56px; }
        .landing { position: relative; z-index: 1; flex: 1; width: 100%; max-width: 1180px; margin: 0 auto; padding: 26px 24px 30px; }
        .foot { position: relative; z-index: 1; text-align: center; color: var(--faint); font-size: 12.5px; letter-spacing: .06em; padding: 22px 24px 28px; }
        .grid-2 { display: grid; grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr); gap: 24px; align-items: start; }
        @media (max-width: 900px) { .grid-2 { grid-template-columns: 1fr; } }
        .page-head { margin-bottom: 26px; }
        .page-head h2 { font-family: var(--serif); font-weight: 500; font-size: 34px; margin: 0 0 4px; }
        .page-head p { margin: 0; color: var(--muted); }

        /* ---------- glass cards ---------- */
        .card { background: var(--glass); border: 1px solid var(--line); border-radius: var(--radius); padding: 30px; margin-bottom: 24px;
                -webkit-backdrop-filter: blur(18px) saturate(140%); backdrop-filter: blur(18px) saturate(140%);
                box-shadow: 0 24px 50px -24px rgba(0,0,0,.6), inset 0 1px 0 rgba(255,255,255,.08); }
        @supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) { .card, .portal, .alert { background: rgba(16,28,54,.92); } }
        .card-title { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap;
                      font-family: var(--serif); font-size: 23px; font-weight: 500; margin: 0 0 22px; padding-bottom: 16px; border-bottom: 1px solid var(--line); }
        .card-title small { font-family: var(--sans); font-size: 12.5px; color: var(--faint); font-weight: 400; letter-spacing: .04em; }
        .muted { color: var(--muted); }

        /* ---------- alerts ---------- */
        .alert { display: flex; gap: 12px; align-items: flex-start; padding: 14px 18px; margin-bottom: 24px; border-radius: 14px;
                 background: var(--glass); border: 1px solid var(--line); border-left: 4px solid var(--gold);
                 -webkit-backdrop-filter: blur(14px); backdrop-filter: blur(14px); animation: rise .5s ease both; }
        .alert svg { flex: none; margin-top: 2px; color: var(--gold2); }
        .alert.ok { border-left-color: var(--ok); } .alert.ok svg { color: var(--ok); }
        .alert.err { border-left-color: var(--err); } .alert.err svg { color: var(--err); }

        /* ---------- forms ---------- */
        .field { margin-bottom: 20px; }
        .lbl { display: block; font-size: 12px; font-weight: 500; color: var(--muted); text-transform: uppercase; letter-spacing: .12em; }
        input, select { width: 100%; margin: 8px 0 0; padding: 13px 15px; font: inherit; font-size: 15px; color: var(--ink);
                        background: rgba(255,255,255,.05); border: 1px solid var(--line); border-radius: 12px; outline: none; transition: .25s; }
        input::placeholder { color: var(--faint); }
        input:focus, select:focus { border-color: var(--gold); background: rgba(255,255,255,.08); box-shadow: 0 0 0 4px rgba(217,184,108,.15); }
        input:-webkit-autofill { -webkit-text-fill-color: var(--ink); -webkit-box-shadow: 0 0 0 40px #14243f inset; caret-color: var(--ink); }
        select { appearance: none; -webkit-appearance: none; cursor: pointer;
                 background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='%239db0cc' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
                 background-repeat: no-repeat; background-position: right 14px center; }
        select option { color: #0a1128; }
        .input-prefix { position: relative; margin-top: 8px; }
        .input-prefix > span { position: absolute; left: 15px; top: 50%; transform: translateY(-50%); color: var(--gold2); font-weight: 500; }
        .input-prefix input { margin: 0; padding-left: 34px; }
        .row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
        @media (max-width: 560px) { .row-2 { grid-template-columns: 1fr; } }
        .hint { font-size: 13px; margin-top: 8px; min-height: 20px; color: var(--faint); }
        .hint.ok { color: var(--ok); } .hint.bad { color: var(--err); }

        .btn { display: inline-flex; align-items: center; justify-content: center; gap: 10px; width: 100%; padding: 14px 22px;
               font: inherit; font-weight: 600; letter-spacing: .04em; color: #1a1405; text-decoration: none; cursor: pointer; border: 0; border-radius: 12px;
               background: linear-gradient(135deg, var(--gold2), var(--gold) 55%, var(--gold-deep));
               box-shadow: 0 12px 26px -12px rgba(217,184,108,.75); transition: .25s; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 16px 30px -12px rgba(217,184,108,.9); }
        .btn:disabled { opacity: .45; cursor: not-allowed; transform: none; box-shadow: none; }
        .btn.inline { width: auto; padding: 11px 20px; }
        .btn-ghost { display: inline-flex; align-items: center; gap: 8px; padding: 11px 20px; border-radius: 12px; text-decoration: none;
                     font: inherit; font-weight: 500; color: var(--ink); background: var(--glass); border: 1px solid var(--line); cursor: pointer; transition: .25s; }
        .btn-ghost:hover { border-color: rgba(217,184,108,.55); color: var(--gold2); transform: translateY(-2px); }
        .btn-sm { padding: 7px 14px; font: inherit; font-size: 13px; border-radius: 9px; cursor: pointer; background: transparent; transition: .25s; }
        .btn-ok { color: var(--ok); border: 1px solid rgba(79,209,161,.55); } .btn-ok:hover { background: var(--ok); color: #05261b; }
        .btn-danger { color: var(--err); border: 1px solid rgba(255,122,133,.5); } .btn-danger:hover { background: var(--err); color: #2b0509; }

        /* ---------- tables + pills ---------- */
        .table-wrap { overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; }
        th { text-align: left; padding: 12px; font-size: 11.5px; font-weight: 500; color: var(--faint); text-transform: uppercase; letter-spacing: .12em; border-bottom: 1px solid var(--line); white-space: nowrap; }
        td { padding: 15px 12px; border-bottom: 1px solid rgba(255,255,255,.06); font-size: 14.5px; }
        tbody tr:hover td { background: rgba(255,255,255,.035); }
        tbody tr:last-child td { border-bottom: 0; }
        .num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
        .mono { font-family: ui-monospace, 'SF Mono', Consolas, monospace; letter-spacing: .05em; }
        .empty { text-align: center; color: var(--faint); padding: 30px 12px; }
        .pill { display: inline-block; padding: 3px 11px; border-radius: 999px; font-size: 12px; letter-spacing: .04em; border: 1px solid var(--line); color: var(--muted); white-space: nowrap; }
        .pill.in { color: var(--ok); border-color: rgba(79,209,161,.4); background: rgba(79,209,161,.08); }
        .pill.out { color: var(--err); border-color: rgba(255,122,133,.4); background: rgba(255,122,133,.08); }
        .pill.gold { color: var(--gold2); border-color: rgba(217,184,108,.45); background: rgba(217,184,108,.09); }
        .pos { color: var(--ok); } .neg { color: var(--err); }
        .actions { display: flex; gap: 8px; justify-content: center; }
        .actions form { margin: 0; }

        /* ---------- stat tiles ---------- */
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 18px; margin-bottom: 24px; }
        .stat { background: var(--glass); border: 1px solid var(--line); border-radius: 16px; padding: 20px 22px;
                -webkit-backdrop-filter: blur(16px); backdrop-filter: blur(16px); }
        .stat small { display: block; font-size: 11.5px; letter-spacing: .12em; text-transform: uppercase; color: var(--faint); }
        .stat b { display: block; margin-top: 6px; font-family: var(--serif); font-size: 28px; font-weight: 500; }

        /* ---------- balance hero (customer) ---------- */
        .balance-card { position: relative; overflow: hidden; }
        .balance-card::after { content: ""; position: absolute; width: 380px; height: 380px; right: -120px; top: -160px; border-radius: 50%;
                               background: radial-gradient(circle, rgba(217,184,108,.22), transparent 65%); pointer-events: none; }
        .balance-top { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
        .balance-label { font-size: 12px; letter-spacing: .14em; text-transform: uppercase; color: var(--muted); }
        .balance-amount { font-family: var(--serif); font-size: clamp(38px, 6vw, 58px); font-weight: 500; margin: 8px 0 22px; line-height: 1.1; }
        .balance-amount span { color: var(--gold2); margin-right: 4px; }
        .btn-row { display: flex; gap: 12px; flex-wrap: wrap; }

        /* ---------- segmented control, choice cards ---------- */
        .seg-wrap { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; padding: 6px; margin-bottom: 24px; border-radius: 14px; background: rgba(255,255,255,.04); border: 1px solid var(--line); }
        .seg { padding: 11px 8px; border: 0; border-radius: 10px; background: transparent; color: var(--muted); font: inherit; font-weight: 500; font-size: 14px; cursor: pointer; transition: .25s; }
        .seg:hover { color: var(--ink); }
        .seg.on { color: #1a1405; background: linear-gradient(135deg, var(--gold2), var(--gold)); box-shadow: 0 8px 18px -10px rgba(217,184,108,.9); }
        .choice-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: 8px; }
        @media (max-width: 560px) { .choice-grid { grid-template-columns: 1fr; } }
        .choice { position: relative; display: block; cursor: pointer; }
        .choice input { position: absolute; opacity: 0; width: 0; height: 0; }
        .choice-body { display: block; padding: 16px 18px; border: 1px solid var(--line); border-radius: 14px; background: rgba(255,255,255,.04); transition: .25s; }
        .choice-body b { display: block; font-weight: 500; }
        .choice-body small { color: var(--faint); }
        .choice:hover .choice-body { border-color: rgba(255,255,255,.3); }
        .choice input:checked + .choice-body { border-color: var(--gold); background: rgba(217,184,108,.1); box-shadow: 0 0 0 4px rgba(217,184,108,.1); }
        .chips { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
        .chip { padding: 6px 13px; border-radius: 999px; border: 1px solid var(--line); background: var(--glass); color: var(--muted); font: inherit; font-size: 13px; cursor: pointer; transition: .25s; }
        .chip:hover { color: var(--gold2); border-color: rgba(217,184,108,.5); }

        /* ---------- side info / steps ---------- */
        .steps { list-style: none; margin: 0; padding: 0; }
        .steps li { display: flex; gap: 14px; padding: 12px 0; }
        .steps .n { flex: none; width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; font-size: 13px; font-weight: 600;
                    color: var(--gold2); border: 1px solid rgba(217,184,108,.45); background: rgba(217,184,108,.08); }
        .steps b { display: block; font-weight: 500; }
        .steps small { color: var(--muted); }
        .summary-row { display: flex; justify-content: space-between; gap: 12px; padding: 11px 0; border-bottom: 1px dashed var(--line); font-size: 14.5px; }
        .summary-row:last-child { border-bottom: 0; }
        .summary-row span:first-child { color: var(--muted); }
        .note { display: flex; gap: 12px; padding: 14px 16px; border-radius: 14px; background: rgba(217,184,108,.07); border: 1px solid rgba(217,184,108,.25); color: var(--muted); font-size: 13.5px; }
        .note svg { flex: none; color: var(--gold2); margin-top: 2px; }

        /* ---------- landing page ---------- */
        .landing-top { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
        .secure-pill { display: inline-flex; align-items: center; gap: 8px; padding: 7px 14px; border-radius: 999px; font-size: 12.5px; color: var(--muted);
                       border: 1px solid var(--line); background: var(--glass); }
        .secure-pill svg { color: var(--ok); }
        .hero { text-align: center; padding: 60px 0 10px; }
        .eyebrow { display: inline-flex; padding: 7px 18px; border-radius: 999px; font-size: 12px; letter-spacing: .2em; text-transform: uppercase;
                   color: var(--gold2); border: 1px solid rgba(217,184,108,.35); background: rgba(217,184,108,.08); }
        .hero h1 { font-family: var(--serif); font-weight: 500; font-size: clamp(40px, 6.4vw, 74px); line-height: 1.08; letter-spacing: -.01em; margin: 24px 0 20px; }
        .hero h1 em { font-style: italic; background: linear-gradient(135deg, #f6e4b0, #d9b86c 60%, #b8924a); -webkit-background-clip: text; background-clip: text; color: transparent; }
        .lead { max-width: 660px; margin: 0 auto; color: var(--muted); font-size: 18px; }
        .portal-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-top: 58px; text-align: left; }
        @media (max-width: 920px) { .portal-grid { grid-template-columns: 1fr; } .trust { grid-template-columns: 1fr !important; } }
        .portal { position: relative; display: flex; flex-direction: column; min-height: 310px; padding: 34px 30px; overflow: hidden;
                  text-decoration: none; color: var(--ink); border-radius: 24px; background: var(--glass); border: 1px solid var(--line);
                  -webkit-backdrop-filter: blur(18px) saturate(140%); backdrop-filter: blur(18px) saturate(140%);
                  box-shadow: 0 30px 60px -30px rgba(0,0,0,.7), inset 0 1px 0 rgba(255,255,255,.1);
                  transition: transform .35s, border-color .35s, box-shadow .35s; }
        .portal::before { content: ""; position: absolute; inset: 0; opacity: 0; transition: opacity .35s;
                          background: radial-gradient(420px 240px at 100% 0%, rgba(217,184,108,.18), transparent 60%); }
        .portal:hover { transform: translateY(-8px); border-color: rgba(217,184,108,.55); box-shadow: 0 40px 70px -30px rgba(0,0,0,.8), 0 0 0 1px rgba(217,184,108,.2); }
        .portal:hover::before { opacity: 1; }
        .portal > * { position: relative; }
        .portal .ico { width: 64px; height: 64px; border-radius: 18px; display: grid; place-items: center; margin-bottom: 26px; color: var(--gold2);
                       background: linear-gradient(145deg, rgba(217,184,108,.22), rgba(217,184,108,.04)); border: 1px solid rgba(217,184,108,.35); }
        .portal h3 { font-family: var(--serif); font-weight: 500; font-size: 28px; margin: 0 0 10px; }
        .portal p { margin: 0 0 26px; color: var(--muted); flex: 1; }
        .portal .go { display: inline-flex; align-items: center; gap: 10px; font-weight: 600; letter-spacing: .04em; color: var(--gold2); }
        .portal .go svg { transition: transform .3s; }
        .portal:hover .go svg { transform: translateX(7px); }
        .portal .tag { position: absolute; top: 24px; right: 24px; padding: 4px 11px; border-radius: 999px; font-size: 11px; letter-spacing: .14em; text-transform: uppercase; color: var(--faint); border: 1px solid var(--line); }
        .trust { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-top: 64px; padding-top: 34px; border-top: 1px solid var(--line); text-align: left; }
        .trust > div { display: flex; gap: 14px; align-items: flex-start; }
        .trust svg { flex: none; color: var(--gold2); margin-top: 3px; }
        .trust b { display: block; font-weight: 500; margin-bottom: 2px; }
        .trust small { color: var(--muted); font-size: 14px; }

        /* ---------- auth pages ---------- */
        .auth-card { max-width: 470px; margin: 34px auto 24px; }
        .auth-ico { width: 62px; height: 62px; margin: 0 auto 16px; border-radius: 18px; display: grid; place-items: center; color: var(--gold2);
                    background: linear-gradient(145deg, rgba(217,184,108,.22), rgba(217,184,108,.04)); border: 1px solid rgba(217,184,108,.35); }
        .auth-title { text-align: center; font-family: var(--serif); font-weight: 500; font-size: 28px; margin: 0 0 6px; }
        .auth-sub { text-align: center; color: var(--muted); margin: 0 0 26px; }
        .auth-links { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 8px; margin-top: 24px; font-size: 14px; }
        .auth-links a { text-decoration: none; color: var(--muted); } .auth-links a:hover { color: var(--gold2); }
        details.demo { margin-top: 22px; padding: 12px 16px; border-radius: 12px; background: rgba(255,255,255,.04); border: 1px dashed var(--line); color: var(--muted); font-size: 13.5px; }
        details.demo summary { cursor: pointer; color: var(--faint); letter-spacing: .08em; text-transform: uppercase; font-size: 11.5px; }
        details.demo code { color: var(--gold2); }

        /* ---------- motion ---------- */
        .rise { opacity: 0; animation: rise .9s cubic-bezier(.2,.7,.2,1) forwards; }
        @keyframes rise { from { opacity: 0; transform: translateY(18px); } to { opacity: 1; transform: none; } }
        @media (max-width: 720px) { .who { display: none; } .nav-inner { padding: 10px 16px; } .container { padding: 24px 16px 44px; } .card { padding: 22px; } }
        @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } .rise { opacity: 1; } }
    </style>
</head>
<body>
    <div class="orb o1"></div><div class="orb o2"></div><div class="orb o3"></div><div class="dots"></div>

    <!-- icon sprite -->
    <svg width="0" height="0" style="position:absolute" aria-hidden="true">
        <defs>
            <symbol id="i-bank" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5l9-6 9 6z"/><path d="M6 12v6M10 12v6M14 12v6M18 12v6"/><path d="M4 21h16M4.5 18h15"/></symbol>
            <symbol id="i-user" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-8 8-8s8 3.6 8 8"/></symbol>
            <symbol id="i-userplus" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="8" r="4"/><path d="M2.5 21c0-4 3.4-7 7.5-7"/><path d="M18 9v6M15 12h6"/></symbol>
            <symbol id="i-shield" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/></symbol>
            <symbol id="i-lock" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></symbol>
            <symbol id="i-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></symbol>
            <symbol id="i-bolt" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></symbol>
            <symbol id="i-ledger" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h12a2 2 0 012 2v14H7a2 2 0 01-2-2z"/><path d="M9 9h6M9 13h6"/></symbol>
            <symbol id="i-check" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.5"/></symbol>
            <symbol id="i-alert" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.5v.5"/></symbol>
            <symbol id="i-swap" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7h13l-4-4M17 17H4l4 4"/></symbol>
        </defs>
    </svg>

<% if (!isLanding) { %>
    <header class="navbar">
        <div class="nav-inner">
            <a class="brand" href="index.jsp">
                <span class="logo"><svg width="20" height="20"><use href="#i-bank"/></svg></span>
                <span class="brand-text">PIVM <em>Bank</em></span>
            </a>
            <nav class="nav-links">
            <% if ("admin".equals(role)) { %>
                <a href="index.jsp" class="active">Dashboard</a>
                <a href="index.jsp#approvals">Approvals</a>
                <a href="index.jsp#ledger">Ledger</a>
                <a href="index.jsp#activity">Activity</a>
            <% } else if ("customer".equals(role)) { %>
                <a href="index.jsp" class="<%= act(pageName.equals("index.jsp")) %>">Overview</a>
                <a href="transact.jsp" class="<%= act(pageName.equals("transact.jsp")) %>">Transfer &amp; Payments</a>
                <a href="index.jsp#history">Statements</a>
            <% } else { %>
                <a href="index.jsp">Home</a>
                <a href="login.jsp?type=customer" class="<%= act(pageName.equals("login.jsp") && navType.equals("customer")) %>">Client Login</a>
                <a href="create.jsp" class="<%= act(pageName.equals("create.jsp")) %>">Open Account</a>
                <a href="login.jsp?type=admin" class="<%= act(pageName.equals("login.jsp") && navType.equals("admin")) %>">Administration</a>
            <% } %>
            </nav>
            <% if (role != null) { %>
            <div class="nav-right">
                <div class="user-chip">
                    <span class="avatar"><%= esc(navInitial) %></span>
                    <span class="who"><b><%= esc(navName) %></b><small><%= esc(navSub) %></small></span>
                </div>
                <form action="BankController" method="POST" style="margin:0;">
                    <input type="hidden" name="action" value="logout">
                    <button type="submit" class="btn-signout">Sign out</button>
                </form>
            </div>
            <% } %>
        </div>
    </header>
<% } %>

<main class="<%= isLanding ? "landing" : "container" %>">
<%
    String msgParam = request.getParameter("msg");
    if (msgParam != null && !msgParam.trim().isEmpty()) {
        String msgType = request.getParameter("t");
        boolean msgOk = "ok".equals(msgType);
        String msgCls = msgOk ? "ok" : ("err".equals(msgType) ? "err" : "");
%>
    <div class="alert <%= msgCls %>"><svg width="20" height="20"><use href="<%= msgOk ? "#i-check" : "#i-alert" %>"/></svg><span><%= esc(msgParam) %></span></div>
<% } %>
