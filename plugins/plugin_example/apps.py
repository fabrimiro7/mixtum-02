from django.apps import AppConfig


class PluginExampleConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "plugins.plugin_example"
    verbose_name = "Plugin Example"

    def ready(self):
        # Decommentare se il plugin usa signals
        # import plugins.plugin_example.signals  # noqa
        pass
