<%@ Page Language="C#" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        if (Session["Username"] == null)
        {
            Response.Redirect("Default.aspx");
        }
        else
        {
            WelcomeLabel.Text = "Welcome back, " + Server.HtmlEncode((string)Session["Username"]) + "!";
        }
    }
</script>
<!DOCTYPE html>
<html>
<head><title>Butters Family Farm Portal - Home</title></head>
<body>
    <form id="form1" runat="server">
        <h1>Butters Family Farm Employee &amp; Guest Portal</h1>
        <p><asp:Label ID="WelcomeLabel" runat="server" /></p>
        <ul>
          <li>Ride &amp; Attraction Maintenance Tickets (coming soon)</li>
          <li>Guest Services Dashboard (coming soon)</li>
          <li>HR Self-Service (coming soon)</li>
        </ul>
    </form>
</body>
</html>
