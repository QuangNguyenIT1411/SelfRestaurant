using System;
using System.Configuration;
using System.Globalization;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;

// Đặt đúng namespace của project bạn
namespace SelfRestaurant.Services
{
    public class EmailService
    {
        private readonly string _smtpHost;
        private readonly int _smtpPort;
        private readonly string _smtpUsername;
        private readonly string _smtpPassword;
        private readonly bool _enableSSL;
        private readonly string _emailFrom;
        private readonly string _emailFromName;

        public EmailService()
        {
            _smtpHost = GetRequiredSetting("SmtpHost", "SELFRESTAURANT_SMTP_HOST");
            _smtpPort = GetRequiredIntSetting("SmtpPort", "SELFRESTAURANT_SMTP_PORT");
            _smtpUsername = GetRequiredSetting("SmtpUsername", "SELFRESTAURANT_SMTP_USERNAME");
            _smtpPassword = GetRequiredSetting("SmtpPassword", "SELFRESTAURANT_SMTP_PASSWORD");
            _enableSSL = GetBoolSetting("SmtpEnableSSL", "SELFRESTAURANT_SMTP_ENABLE_SSL", defaultValue: true);
            _emailFrom = GetRequiredSetting("EmailFrom", "SELFRESTAURANT_EMAIL_FROM");
            _emailFromName = GetRequiredSetting("EmailFromName", "SELFRESTAURANT_EMAIL_FROM_NAME");
        }

        private static string GetRequiredSetting(string appSettingKey, string envVarKey)
        {
            var value = ConfigurationManager.AppSettings[appSettingKey];
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value.Trim();
            }

            value = Environment.GetEnvironmentVariable(envVarKey);
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value.Trim();
            }

            throw new InvalidOperationException(
                $"Missing required setting '{appSettingKey}'. Set appSettings['{appSettingKey}'] or env var '{envVarKey}'.");
        }

        private static int GetRequiredIntSetting(string appSettingKey, string envVarKey)
        {
            var value = ConfigurationManager.AppSettings[appSettingKey];
            if (string.IsNullOrWhiteSpace(value))
            {
                value = Environment.GetEnvironmentVariable(envVarKey);
            }

            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException(
                    $"Missing required setting '{appSettingKey}'. Set appSettings['{appSettingKey}'] or env var '{envVarKey}'.");
            }

            if (!int.TryParse(value.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var result))
            {
                throw new InvalidOperationException($"Invalid int value for '{appSettingKey}': '{value}'.");
            }

            return result;
        }

        private static bool GetBoolSetting(string appSettingKey, string envVarKey, bool defaultValue)
        {
            var value = ConfigurationManager.AppSettings[appSettingKey];
            if (string.IsNullOrWhiteSpace(value))
            {
                value = Environment.GetEnvironmentVariable(envVarKey);
            }

            if (string.IsNullOrWhiteSpace(value))
            {
                return defaultValue;
            }

            if (!bool.TryParse(value.Trim(), out var result))
            {
                return defaultValue;
            }

            return result;
        }

        public async Task<bool> SendEmailAsync(string toEmail, string subject, string body)
        {
            try
            {
                using (var message = new MailMessage())
                {
                    message.From = new MailAddress(_emailFrom, _emailFromName);
                    message.To.Add(new MailAddress(toEmail));
                    message.Subject = subject;
                    message.Body = body;
                    message.IsBodyHtml = true;

                    using (var smtp = new SmtpClient(_smtpHost, _smtpPort))
                    {
                        smtp.Credentials = new NetworkCredential(_smtpUsername, _smtpPassword);
                        smtp.EnableSsl = _enableSSL;
                        await smtp.SendMailAsync(message);
                    }
                }
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Email Error: {ex.Message}");
                return false;
            }
        }

        public string GetPasswordResetEmailBody(string customerName, string resetLink)
        {
            return $@"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{
            font-family: 'Arial', sans-serif;
            background-color: #f4f4f4;
            margin: 0;
            padding: 0;
        }}
        .container {{
            max-width: 600px;
            margin: 20px auto;
            background-color: #ffffff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }}
        .header h1 {{
            margin: 0;
            font-size: 28px;
        }}
        .content {{
            padding: 30px;
            color: #333333;
        }}
        .content h2 {{
            color: #d9534f;
            margin-top: 0;
        }}
        .content p {{
            line-height: 1.6;
            margin: 15px 0;
        }}
        .btn {{
            display: inline-block;
            padding: 12px 30px;
            background-color: #d9534f;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin: 20px 0;
            font-weight: bold;
        }}
        .btn:hover {{
            background-color: #c9423f;
        }}
        .footer {{
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #6c757d;
        }}
        .warning {{
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 12px;
            margin: 20px 0;
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>🍽️ Self Restaurant</h1>
        </div>
        <div class='content'>
            <h2>Đặt Lại Mật Khẩu</h2>
            <p>Xin chào <strong>{customerName}</strong>,</p>
            <p>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn.</p>
            <p>Vui lòng nhấp vào nút bên dưới để đặt lại mật khẩu:</p>
            
            <div style='text-align: center;'>
                <a href='{resetLink}' class='btn'>Đặt Lại Mật Khẩu</a>
            </div>

            <div class='warning'>
                <strong>⚠️ Lưu ý:</strong>
                <ul style='margin: 10px 0; padding-left: 20px;'>
                    <li>Link này chỉ có hiệu lực trong vòng <strong>30 phút</strong></li>
                    <li>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này</li>
                    <li>Không chia sẻ link này với bất kỳ ai</li>
                </ul>
            </div>

            <p>Hoặc copy và paste link sau vào trình duyệt:</p>
            <p style='word-break: break-all; color: #667eea;'>{resetLink}</p>

            <p style='margin-top: 30px;'>
                Trân trọng,<br>
                <strong>Đội ngũ Self Restaurant</strong>
            </p>
        </div>
        <div class='footer'>
            <p>© 2025 Self Restaurant. All rights reserved.</p>
            <p>Đây là email tự động, vui lòng không trả lời email này.</p>
        </div>
    </div>
</body>
</html>";
        }
    }
}
