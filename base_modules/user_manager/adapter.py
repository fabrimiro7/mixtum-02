"""
Allauth AccountAdapter that sends all account-related emails through base_modules.mailer.

This is core Mixtum infrastructure (🟦). Derived projects that need to customize
signup/email behaviour should subclass MailerAccountAdapter and set ACCOUNT_ADAPTER
to their adapter; emails still go through the mailer.
"""
from allauth.account.adapter import DefaultAccountAdapter

from base_modules.mailer.models import Email as EmailModel, EmailStatus
from base_modules.mailer.services import send_email_now


class MailerAccountAdapter(DefaultAccountAdapter):
    """
    Sends allauth account emails (confirmation, password reset, etc.) via the mailer app.
    Uses the same pipeline (tracking, optional queue) as the rest of the application.
    """

    def send_mail(self, template_prefix, email, context):
        msg = self.render_mail(template_prefix, email, context)
        body_text = msg.body or ""
        body_html = ""
        if getattr(msg, "alternatives", None):
            for content, mimetype in msg.alternatives:
                if mimetype == "text/html":
                    body_html = content or ""
                    break

        mailer_email = EmailModel(
            to=[email],
            subject=msg.subject or "",
            body_text=body_text,
            body_html=body_html or "",
            status=EmailStatus.DRAFT,
        )
        mailer_email.save()

        ok = send_email_now(mailer_email)
        if not ok:
            raise RuntimeError("Mailer did not send the message.")
