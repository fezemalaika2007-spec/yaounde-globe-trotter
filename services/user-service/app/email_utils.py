"""
user-service/email_utils.py

Utility for sending verification and password reset emails via SMTP.
If SMTP environment variables are set in services/.env, emails are delivered
to the user's real inbox. Otherwise, email contents are logged to standard output
for local development/testing.
"""
import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logger = logging.getLogger(__name__)


def send_email(to_email: str, subject: str, body_text: str, body_html: str = None) -> bool:
    """Send an email to *to_email*.

    Returns True on success or logged output in dev mode.
    """
    smtp_server = os.environ.get("SMTP_SERVER", "").strip()
    smtp_port = int(os.environ.get("SMTP_PORT", "587"))
    smtp_username = os.environ.get("SMTP_USERNAME", "").strip()
    smtp_password = os.environ.get("SMTP_PASSWORD", "").strip()
    smtp_from = os.environ.get("SMTP_FROM_EMAIL", smtp_username or "noreply@yaoundetrip.com").strip()

    if not smtp_server or not smtp_username or not smtp_password:
        print(
            f"\n========================================\n"
            f"[EMAIL TO {to_email}]\n"
            f"Subject: {subject}\n\n"
            f"{body_text}\n"
            f"========================================\n",
            flush=True,
        )
        return True

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = smtp_from
        msg["To"] = to_email

        msg.attach(MIMEText(body_text, "plain"))
        if body_html:
            msg.attach(MIMEText(body_html, "html"))

        with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
            server.starttls()
            server.login(smtp_username, smtp_password)
            server.sendmail(smtp_from, [to_email], msg.as_string())
        logger.info(f"Email successfully sent to {to_email}")
        return True
    except Exception as e:
        logger.error(f"Failed to send email to {to_email}: {e}")
        print(f"[SMTP ERROR] {e}. Email content was:\n{body_text}", flush=True)
        return False
