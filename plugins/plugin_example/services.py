from django.shortcuts import get_object_or_404
from .models import ExampleModel


class ExampleModelService:
    """
    Business logic per ExampleModel.
    Tutti i metodi sono statici — la classe è usata come namespace, non istanziata.
    """

    @staticmethod
    def get_list(workspace):
        """Ritorna tutti gli oggetti del workspace."""
        return ExampleModel.objects.filter(workspace=workspace)

    @staticmethod
    def get_by_id(pk, workspace):
        """Ritorna un singolo oggetto. Lancia 404 se non trovato o non accessibile."""
        return get_object_or_404(
            ExampleModel,
            pk=pk,
            workspace=workspace,
        )

    @staticmethod
    def create(data, user, workspace):
        """Crea un nuovo oggetto."""
        return ExampleModel.objects.create(
            **data,
            created_by=user,
            workspace=workspace,
        )

    @staticmethod
    def update(instance, data):
        """Aggiorna un oggetto esistente."""
        for attr, value in data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance

    @staticmethod
    def delete(instance):
        """Elimina un oggetto."""
        instance.delete()
