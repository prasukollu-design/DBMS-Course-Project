<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="header.jsp" %>
<%
    boolean adminLogin = "admin".equals(request.getParameter("type"));
    String loginType = adminLogin ? "admin" : "customer";
%>

<div class="card auth-card rise">
    <div class="auth-ico"><svg width="30" height="30"><use href="<%= adminLogin ? "#i-shield" : "#i-user" %>"/></svg></div>
    <h2 class="auth-title"><%= adminLogin ? "Administration Login" : "Client Sign In" %></h2>
    <p class="auth-sub"><%= adminLogin ? "Authorised bank staff only." : "Enter your credentials to access your accounts." %></p>

    <form action="BankController" method="POST" autocomplete="off">
        <input type="hidden" name="action" value="login">
        <input type="hidden" name="type" value="<%= loginType %>">

        <div class="field">
            <label class="lbl" for="username">Username</label>
            <input type="text" id="username" name="username" required autofocus>
        </div>
        <div class="field">
            <label class="lbl" for="pin"><%= adminLogin ? "Password" : "Secure PIN" %></label>
            <input type="password" id="pin" name="pin" required>
        </div>
        <button type="submit" class="btn" style="margin-top:6px;"><%= adminLogin ? "Authorise Access" : "Access Account" %> <svg width="18" height="18"><use href="#i-arrow"/></svg></button>
    </form>

    <div class="auth-links">
        <a href="index.jsp">&larr; Back to home</a>
        <% if (adminLogin) { %>
            <a href="login.jsp?type=customer">Client sign in</a>
        <% } else { %>
            <a href="create.jsp">New here? Open an account</a>
        <% } %>
    </div>

    <details class="demo">
        <summary>Demo credentials</summary>
        <% if (adminLogin) { %>
            Username <code>admin</code> &middot; Password <code>admin123</code>
        <% } else { %>
            <code>vishnu_m</code>, <code>ishanth_r</code> or <code>prasanna_k</code> &middot; PIN <code>1234</code>
        <% } %>
    </details>
</div>

<%@ include file="footer.jsp" %>
