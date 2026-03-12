from django.contrib import admin
from .models import ExampleModel


@admin.register(ExampleModel)
class ExampleModelAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "workspace", "created_by", "created_at"]
    list_filter = ["workspace", "created_at"]
    search_fields = ["name"]
    readonly_fields = ["created_at", "updated_at"]
