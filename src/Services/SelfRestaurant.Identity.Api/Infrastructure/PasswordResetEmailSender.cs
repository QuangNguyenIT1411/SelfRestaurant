using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;

namespace SelfRestaurant.Identity.Api.Infrastructure;

public sealed class PasswordResetEmailSender
{
    private readonly SmtpOptions _options;
    private readonly ILogger<PasswordResetEmailSender> _logger;

    public PasswordResetEmailSender(IOptions<SmtpOptions> options, ILogger<PasswordResetEmailSender> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public bool IsEnabled =>
        _options.Enabled
        && !string.IsNullOrWhiteSpace(_options.Host)
        && _options.Port > 0
        && !string.IsNullOrWhiteSpace(_options.FromEmail);

    public async Task<bool> TrySendAsync(
        string toEmail,
        string? toName,
        string resetToken,
        CancellationToken cancellationToken)
    {
        if (!IsEnabled)
        {
            return false;
        }

        try
        {
            using var message = new MailMessage
            {
                Subject = "SelfRestaurant - Ma dat lai mat khau",
                IsBodyHtml = true,
                Body = BuildHtmlBody(toName, resetToken),
            };

            message.From = new MailAddress(_options.FromEmail, _options.FromName);
            message.To.Add(new MailAddress(toEmail, toName ?? toEmail));

            using var smtp = new SmtpClient(_options.Host, _options.Port)
            {
                EnableSsl = _options.UseSsl,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                Timeout = _options.TimeoutMs,
            };

            if (!string.IsNullOrWhiteSpace(_options.Username))
            {
                smtp.Credentials = new NetworkCredential(_options.Username, _options.Password);
            }

            await smtp.SendMailAsync(message).WaitAsync(cancellationToken);
            _logger.LogInformation("Password reset email sent to {Email}", toEmail);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send password reset email to {Email}", toEmail);
            return false;
        }
    }

    private static string BuildHtmlBody(string? customerName, string resetToken)
    {
        var displayName = string.IsNullOrWhiteSpace(customerName) ? "Ban" : customerName.Trim();

        return $@"
<div style=""font-family:Segoe UI,Arial,sans-serif;line-height:1.6;color:#1f2937"">
  <h2 style=""margin-bottom:12px"">Dat lai mat khau SelfRestaurant</h2>
  <p>Xin chao {WebUtility.HtmlEncode(displayName)},</p>
  <p>Nhap ma sau de dat lai mat khau cua ban:</p>
  <p style=""font-size:18px;font-weight:700;letter-spacing:1px"">{WebUtility.HtmlEncode(resetToken)}</p>
  <p>Neu ban khong yeu cau thao tac nay, hay bo qua email nay.</p>
</div>";
    }
}
