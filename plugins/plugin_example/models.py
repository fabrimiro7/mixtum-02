from django.db import models
from base_modules.user_manager.models import User
from base_modules.workspace.models import Workspace


class ExampleModel(models.Model):
    """
    Modello di esempio. Sostituire con il modello reale del plugin.
    """
    workspace = models.ForeignKey(
        Workspace,
        on_delete=models.CASCADE,
        related_name="example_set",
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="example_created",
    )
    name = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Example"
        verbose_name_plural = "Examples"

    def __str__(self):
        return self.name
