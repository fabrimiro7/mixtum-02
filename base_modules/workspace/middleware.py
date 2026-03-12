from django.http import JsonResponse
from .models import WorkspaceUser


class WorkspaceMiddleware:
    """
    Middleware che legge l'header X-Workspace-Id da ogni request autenticata,
    verifica che l'utente appartenga al workspace richiesto, e aggiunge
    request.workspace disponibile in tutte le views e i services.

    Se l'header non è presente, usa il primo workspace disponibile
    dell'utente come fallback.

    Header atteso: X-Workspace-Id: <int>
    Mandato automaticamente dal WorkspaceInterceptor Angular.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.workspace = None

        if request.user.is_authenticated:
            workspace_id = request.headers.get("X-Workspace-Id")

            if workspace_id:
                try:
                    membership = WorkspaceUser.objects.select_related(
                        "workspace"
                    ).get(
                        user=request.user,
                        workspace_id=workspace_id,
                    )
                    request.workspace = membership.workspace
                except WorkspaceUser.DoesNotExist:
                    return JsonResponse(
                        {"detail": "Workspace non valido o accesso negato."},
                        status=403,
                    )
                except (ValueError, TypeError):
                    return JsonResponse(
                        {"detail": "X-Workspace-Id non valido."},
                        status=400,
                    )
            else:
                membership = WorkspaceUser.objects.select_related(
                    "workspace"
                ).filter(user=request.user).order_by("date_joined").first()

                if membership:
                    request.workspace = membership.workspace

        return self.get_response(request)
