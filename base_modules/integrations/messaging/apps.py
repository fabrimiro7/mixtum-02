from django.apps import AppConfig


class MessagingConfig(AppConfig):
    name = 'base_modules.integrations.messaging'
    verbose_name = "Twilio WhatsApp Integration"

    def ready(self):
        # Import signals if needed
        pass
