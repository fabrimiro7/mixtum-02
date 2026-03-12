from rest_framework import serializers
from .models import ExampleModel


class ExampleModelSerializer(serializers.ModelSerializer):
    """Serializer di lettura."""
    class Meta:
        model = ExampleModel
        fields = ["id", "workspace", "created_by", "name", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at", "created_by"]


class ExampleModelWriteSerializer(serializers.ModelSerializer):
    """Serializer di scrittura — solo campi scrivibili dall'utente."""
    class Meta:
        model = ExampleModel
        fields = ["name"]
