<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="header.jsp" %>

<div class="page-head rise">
    <h2>Open a PIVM Account</h2>
    <p>Tell us a little about yourself. Our administration team will review and activate your account.</p>
</div>

<div class="grid-2">
    <div class="card rise" style="animation-delay:.1s">
        <div class="card-title">Account Application</div>
        <form action="BankController" method="POST" autocomplete="off">
            <input type="hidden" name="action" value="create">

            <div class="field">
                <label class="lbl" for="customer_name">Full legal name</label>
                <input type="text" id="customer_name" name="customer_name" required maxlength="80" placeholder="As on your ID">
            </div>

            <div class="row-2">
                <div class="field">
                    <label class="lbl" for="username">Choose a username</label>
                    <input type="text" id="username" name="username" required pattern="[A-Za-z0-9_.]{3,20}" maxlength="20" placeholder="e.g. rahul_k">
                </div>
                <div class="field">
                    <label class="lbl" for="pin">Set a 4-digit PIN</label>
                    <input type="password" id="pin" name="pin" required pattern="[0-9]{4}" inputmode="numeric" maxlength="4" placeholder="&bull;&bull;&bull;&bull;">
                </div>
            </div>

            <div class="field">
                <span class="lbl">Account type</span>
                <div class="choice-grid">
                    <label class="choice">
                        <input type="radio" name="account_type" value="Savings" checked>
                        <span class="choice-body"><b>Standard Savings</b><small>Everyday banking for individuals</small></span>
                    </label>
                    <label class="choice">
                        <input type="radio" name="account_type" value="Current">
                        <span class="choice-body"><b>Corporate Current</b><small>Built for business transactions</small></span>
                    </label>
                </div>
            </div>

            <div class="field">
                <label class="lbl" for="balance">Opening deposit</label>
                <div class="input-prefix"><span>&#8377;</span><input type="number" id="balance" step="0.01" name="balance" required min="500" placeholder="Minimum 500"></div>
            </div>

            <button type="submit" class="btn" style="margin-top:6px;">Submit Application <svg width="18" height="18"><use href="#i-arrow"/></svg></button>
        </form>
    </div>

    <div class="card rise" style="animation-delay:.2s">
        <div class="card-title">What happens next</div>
        <ul class="steps">
            <li><span class="n">1</span><span><b>Submit your application</b><small>Your details are recorded with a Pending status.</small></span></li>
            <li><span class="n">2</span><span><b>Administrative review</b><small>A bank administrator approves or rejects the request.</small></span></li>
            <li><span class="n">3</span><span><b>Start banking</b><small>Once approved, sign in from the Client Portal with your username and PIN.</small></span></li>
        </ul>
        <div class="note" style="margin-top:18px;"><svg width="18" height="18"><use href="#i-shield"/></svg><span>Your PIN authorises every transaction. Never share it with anyone.</span></div>
        <div style="margin-top:22px;"><a href="login.jsp?type=customer" class="muted" style="text-decoration:none;">Already a client? <span style="color:var(--gold2)">Sign in &rarr;</span></a></div>
    </div>
</div>

<%@ include file="footer.jsp" %>
