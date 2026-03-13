# Mixtum — Standard di sviluppo Plugin

Questo documento definisce lo standard obbligatorio per la creazione e lo sviluppo
di plugin nel framework Mixtum. Si applica a tutti i prodotti derivati (ED Ticket,
Fiscally, progetti custom). È destinato a sviluppatori umani e a sistemi AI che
generano codice automaticamente.

---

## Indice

1. [Struttura file obbligatoria](#1-struttura-file-obbligatoria)
2. [File opzionali](#2-file-opzionali)
3. [Regole generali](#3-regole-generali)
4. [Skeleton di ogni file obbligatorio](#4-skeleton-di-ogni-file-obbligatorio)
5. [Skeleton dei file opzionali](#5-skeleton-dei-file-opzionali)
6. [Convenzioni di naming](#6-convenzioni-di-naming)
7. [Regole API](#7-regole-api)
8. [Regole Models](#8-regole-models)
9. [Regole Services](#9-regole-services)
10. [Regole Tests](#10-regole-tests)
11. [Checklist prima di un commit](#11-checklist-prima-di-un-commit)

---

## 1. Struttura file obbligatoria

Ogni plugin DEVE avere esattamente questa struttura. Nessun file obbligatorio
può essere omesso, anche se inizialmente contiene solo lo skeleton vuoto.

```
plugins/
└── nome_plugin/
    ├── __init__.py
    ├── apps.py
    ├── models.py
    ├── serializers.py
    ├── views.py
    ├── urls.py
    ├── admin.py
    ├── services.py
    ├── migrations/
    │   └── __init__.py
    └── tests/
        ├── __init__.py
        ├── test_models.py
        ├── test_views.py
        └── test_services.py
```

---

## 2. File opzionali

I file seguenti vanno aggiunti SOLO quando effettivamente necessari.
Non creare file opzionali vuoti.

| File | Quando aggiungerlo |
|---|---|
| `permissions.py` | Il plugin ha logica di accesso specifica per ruolo o ownership |
| `signals.py` | Il plugin reagisce a eventi di altri modelli via Django signals |
| `tasks.py` | Il plugin ha operazioni asincrone via Celery |
| `filters.py` | Le list view hanno filtri query complessi (oltre i parametri base) |
| `pagination.py` | Il plugin usa una paginazione diversa da quella globale |
| `managers.py` | I modelli hanno queryset logic complessa e riutilizzabile |
| `constants.py` | Il plugin ha costanti condivise tra più file |
| `exceptions.py` | Il plugin ha eccezioni custom |

---

## 3. Regole generali

### 3.1 Dipendenze consentite

Un plugin PUÒ importare da:
- `base_modules.*` — qualsiasi modulo base di Mixtum
- `django.*` — framework Django
- `rest_framework.*` — Django REST Framework
- librerie Python di terze parti installate in `requirements.txt`

Un plugin NON PUÒ importare da:
- altri plugin (`plugins.*`)

Se due plugin devono comunicare, usare Django signals o un service layer
che accetta oggetti già risolti come parametri.

```python
# VIETATO
from plugins.project_manager.models import Project  # ❌

# CORRETTO — il project viene passato dall'esterno
class TicketService:
    @staticmethod
    def create(data, user, project):  # ✅ project arrivà dalla view
        ...
```

### 3.2 Business logic

- Le `views.py` NON contengono business logic. Chiamano solo i services.
- I `models.py` NON contengono business logic. Contengono solo struttura dati
  e metodi di utilità semplici (es. `__str__`, `get_absolute_url`, properties).
- Tutta la business logic sta in `services.py`.

### 3.3 Accesso al database

- Le views NON fanno query dirette. Usano i services.
- I services usano i manager dei modelli o queryset espliciti.
- Le query complesse e riutilizzabili stanno in `managers.py`.

---

## 4. Skeleton di ogni file obbligatorio

Sostituire `nome_plugin` con il nome reale del plugin in snake_case.
Sostituire `NomePlugin` con il nome in PascalCase.

---

### `__init__.py`

```python
# Lasciare vuoto
```

---

### `apps.py`

```python
from django.apps import AppConfig


class NomePluginConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "plugins.nome_plugin"
    verbose_name = "Nome Plugin"

    def ready(self):
        # Importare signals qui se il plugin li usa
        # import plugins.nome_plugin.signals  # noqa
        pass
```

---

### `models.py`

```python
from django.db import models
from base_modules.user_manager.models import User
from base_modules.workspace.models import Workspace


class NomeModello(models.Model):
    """
    Descrizione breve del modello.
    """
    workspace = models.ForeignKey(
        Workspace,
        on_delete=models.CASCADE,
        related_name="nome_modello_set",
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="nome_modello_created",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Nome Modello"
        verbose_name_plural = "Nome Modelli"

    def __str__(self):
        return f"{self.__class__.__name__} #{self.pk}"
```

**Regole models:**
- Ogni modello DEVE avere `created_at` e `updated_at`.
- Ogni modello DEVE avere `__str__`.
- Ogni modello DEVE avere `Meta` con almeno `ordering` e `verbose_name`.
- I modelli legati a un workspace DEVONO avere FK verso `Workspace`.

---

### `serializers.py`

```python
from rest_framework import serializers
from .models import NomeModello


class NomeModelloSerializer(serializers.ModelSerializer):
    class Meta:
        model = NomeModello
        fields = [
            "id",
            "workspace",
            "created_by",
            "created_at",
            "updated_at",
            # aggiungere campi specifici
        ]
        read_only_fields = ["id", "created_at", "updated_at", "created_by"]


class NomeModelloWriteSerializer(serializers.ModelSerializer):
    """
    Serializer usato per create e update.
    Separato dal serializer di lettura per controllo esplicito sui campi scrivibili.
    """
    class Meta:
        model = NomeModello
        fields = [
            # solo i campi che l'utente può scrivere
        ]
```

**Regole serializers:**
- Usare serializer separati per lettura e scrittura quando i campi differiscono.
- `id`, `created_at`, `updated_at`, `created_by` sono sempre `read_only`.
- Non usare `fields = "__all__"`.

---

### `views.py`

```python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from .models import NomeModello
from .serializers import NomeModelloSerializer, NomeModelloWriteSerializer
from .services import NomeModelloService


class NomeModelloListView(APIView):
    """
    GET  /api/nome-plugin/nome-modello/        → lista
    POST /api/nome-plugin/nome-modello/        → crea
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        workspace = request.user.current_workspace
        items = NomeModelloService.get_list(workspace=workspace)
        serializer = NomeModelloSerializer(items, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = NomeModelloWriteSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        item = NomeModelloService.create(
            data=serializer.validated_data,
            user=request.user,
        )
        return Response(NomeModelloSerializer(item).data, status=status.HTTP_201_CREATED)


class NomeModelloDetailView(APIView):
    """
    GET    /api/nome-plugin/nome-modello/<pk>/ → dettaglio
    PATCH  /api/nome-plugin/nome-modello/<pk>/ → aggiorna
    DELETE /api/nome-plugin/nome-modello/<pk>/ → elimina
    """
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        return NomeModelloService.get_by_id(pk=pk, user=user)

    def get(self, request, pk):
        item = self.get_object(pk, request.user)
        return Response(NomeModelloSerializer(item).data)

    def patch(self, request, pk):
        item = self.get_object(pk, request.user)
        serializer = NomeModelloWriteSerializer(item, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        item = NomeModelloService.update(
            instance=item,
            data=serializer.validated_data,
            user=request.user,
        )
        return Response(NomeModelloSerializer(item).data)

    def delete(self, request, pk):
        item = self.get_object(pk, request.user)
        NomeModelloService.delete(instance=item, user=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)
```

**Regole views:**
- Ogni view DEVE avere `permission_classes` esplicito.
- Le views NON contengono logica. Delegano tutto ai services.
- Usare sempre `status.*` di DRF, mai numeri hardcoded (es. `200`, `404`).
- Ogni classe view DEVE avere un docstring con i metodi HTTP e gli url che gestisce.

---

### `urls.py`

```python
from django.urls import path
from . import views

app_name = "nome_plugin"

urlpatterns = [
    path(
        "nome-modello/",
        views.NomeModelloListView.as_view(),
        name="nome-modello-list",
    ),
    path(
        "nome-modello/<int:pk>/",
        views.NomeModelloDetailView.as_view(),
        name="nome-modello-detail",
    ),
]
```

**Regole urls:**
- `app_name` è obbligatorio.
- Ogni url DEVE avere un `name`.
- Gli url usano kebab-case (`nome-modello`, non `nomeModello` né `nome_modello`).
- Gli url terminano sempre con `/`.

---

### `admin.py`

```python
from django.contrib import admin
from .models import NomeModello


@admin.register(NomeModello)
class NomeModelloAdmin(admin.ModelAdmin):
    list_display = ["id", "workspace", "created_by", "created_at"]
    list_filter = ["workspace", "created_at"]
    search_fields = ["id"]
    readonly_fields = ["created_at", "updated_at"]
```

**Regole admin:**
- Ogni modello DEVE essere registrato in admin.
- `list_display` DEVE includere almeno `id` e `created_at`.
- `readonly_fields` DEVE includere `created_at` e `updated_at`.

---

### `services.py`

```python
from django.shortcuts import get_object_or_404
from .models import NomeModello


class NomeModelloService:
    """
    Business logic per NomeModello.
    Tutti i metodi sono statici — la classe è usata come namespace, non istanziata.
    """

    @staticmethod
    def get_list(workspace):
        """
        Ritorna tutti gli oggetti del workspace.
        """
        return NomeModello.objects.filter(workspace=workspace)

    @staticmethod
    def get_by_id(pk, user):
        """
        Ritorna un singolo oggetto. Lancia 404 se non trovato.
        Verificare qui eventuali permessi di accesso all'oggetto.
        """
        return get_object_or_404(
            NomeModello,
            pk=pk,
            workspace=user.current_workspace,
        )

    @staticmethod
    def create(data, user):
        """
        Crea un nuovo oggetto.
        """
        return NomeModello.objects.create(
            **data,
            created_by=user,
            workspace=user.current_workspace,
        )

    @staticmethod
    def update(instance, data, user):
        """
        Aggiorna un oggetto esistente.
        """
        for attr, value in data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance

    @staticmethod
    def delete(instance, user):
        """
        Elimina un oggetto.
        """
        instance.delete()
```

**Regole services:**
- Tutti i metodi sono `@staticmethod`.
- La classe NON viene istanziata — è un namespace per la logica.
- Ogni metodo DEVE avere un docstring, anche minimo.
- La logica di permessi sull'oggetto (ownership, ruolo) sta qui, non nella view.
- I metodi che falliscono per logica di business lanciano eccezioni esplicite,
  non ritornano `None` silenziosamente.

---

### `migrations/__init__.py`

```python
# Lasciare vuoto
```

---

### `tests/__init__.py`

```python
# Lasciare vuoto
```

---

### `tests/test_models.py`

```python
from django.test import TestCase
from django.contrib.auth import get_user_model

User = get_user_model()


class NomeModelloModelTest(TestCase):
    """
    Test per il modello NomeModello.
    """

    def setUp(self):
        # Setup dati comuni a tutti i test di questa classe
        pass

    def test_str(self):
        # Verificare che __str__ ritorni un valore sensato
        pass

    def test_created_at_auto_set(self):
        # Verificare che created_at venga impostato automaticamente
        pass
```

---

### `tests/test_views.py`

```python
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

User = get_user_model()


class NomeModelloListViewTest(TestCase):
    """
    Test per NomeModelloListView.
    """

    def setUp(self):
        self.client = APIClient()
        # self.user = User.objects.create_user(...)
        # self.client.force_authenticate(user=self.user)

    def test_list_requires_authentication(self):
        # Verificare che la view ritorni 401 senza autenticazione
        pass

    def test_list_returns_200(self):
        # Verificare che la view ritorni 200 con utente autenticato
        pass

    def test_create_returns_201(self):
        # Verificare che la creazione ritorni 201
        pass
```

---

### `tests/test_services.py`

```python
from django.test import TestCase


class NomeModelloServiceTest(TestCase):
    """
    Test per NomeModelloService.
    """

    def setUp(self):
        pass

    def test_create(self):
        # Verificare che create() ritorni un oggetto valido
        pass

    def test_get_by_id_raises_404_if_not_found(self):
        # Verificare che get_by_id() lanci 404 se l'oggetto non esiste
        pass
```

---

## 5. Skeleton dei file opzionali

---

### `permissions.py`

```python
from rest_framework.permissions import BasePermission


class IsWorkspaceMember(BasePermission):
    """
    Permette l'accesso solo ai membri del workspace corrente.
    """
    message = "Non hai i permessi per accedere a questa risorsa."

    def has_permission(self, request, view):
        # logica permesso a livello di view
        return True

    def has_object_permission(self, request, view, obj):
        # logica permesso a livello di oggetto
        return obj.workspace == request.user.current_workspace
```

---

### `signals.py`

```python
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import NomeModello


@receiver(post_save, sender=NomeModello)
def on_nome_modello_saved(sender, instance, created, **kwargs):
    """
    Eseguito dopo il salvataggio di NomeModello.
    """
    if created:
        pass  # logica per nuovi oggetti
    else:
        pass  # logica per oggetti aggiornati


@receiver(post_delete, sender=NomeModello)
def on_nome_modello_deleted(sender, instance, **kwargs):
    """
    Eseguito dopo l'eliminazione di NomeModello.
    """
    pass
```

**Nota:** i signals vanno importati in `apps.py` nel metodo `ready()`.

```python
# apps.py
def ready(self):
    import plugins.nome_plugin.signals  # noqa
```

---

### `tasks.py`

```python
from mixtum_core.celery import app


@app.task(bind=True, max_retries=3)
def nome_task(self, oggetto_id):
    """
    Descrizione del task.
    bind=True permette di accedere a self per retry.
    max_retries=3 è il default consigliato.
    """
    try:
        # logica del task
        pass
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60)
```

---

### `filters.py`

```python
from django.db.models import Q


class NomeModelloFilter:
    """
    Logica di filtro per NomeModello.
    Usato nei services, non nelle views direttamente.
    """

    @staticmethod
    def apply(queryset, params):
        search = params.get("search")
        if search:
            queryset = queryset.filter(
                Q(campo_uno__icontains=search) |
                Q(campo_due__icontains=search)
            )
        return queryset
```

---

### `managers.py`

```python
from django.db import models


class NomeModelloQuerySet(models.QuerySet):

    def attivi(self):
        return self.filter(attivo=True)

    def del_workspace(self, workspace):
        return self.filter(workspace=workspace)


class NomeModelloManager(models.Manager):

    def get_queryset(self):
        return NomeModelloQuerySet(self.model, using=self._db)

    def attivi(self):
        return self.get_queryset().attivi()

    def del_workspace(self, workspace):
        return self.get_queryset().del_workspace(workspace)
```

Usato nel model:

```python
class NomeModello(models.Model):
    objects = NomeModelloManager()
    ...
```

---

### `constants.py`

```python
class StatoNomeModello(models.TextChoices):
    BOZZA = "draft", "Bozza"
    ATTIVO = "active", "Attivo"
    ARCHIVIATO = "archived", "Archiviato"
```

---

### `exceptions.py`

```python
from rest_framework.exceptions import APIException
from rest_framework import status


class NomeModelloNonTrovato(APIException):
    status_code = status.HTTP_404_NOT_FOUND
    default_detail = "Oggetto non trovato."
    default_code = "not_found"


class OperazioneNonConsentita(APIException):
    status_code = status.HTTP_403_FORBIDDEN
    default_detail = "Operazione non consentita."
    default_code = "forbidden"
```

---

## 6. Convenzioni di naming

| Elemento | Convenzione | Esempio |
|---|---|---|
| Cartella plugin | snake_case | `ticket_manager` |
| Classe modello | PascalCase | `Ticket`, `TicketMessage` |
| Classe service | PascalCase + `Service` | `TicketService` |
| Classe serializer | PascalCase + `Serializer` | `TicketSerializer` |
| Classe serializer scrittura | PascalCase + `WriteSerializer` | `TicketWriteSerializer` |
| Classe view lista | PascalCase + `ListView` | `TicketListView` |
| Classe view dettaglio | PascalCase + `DetailView` | `TicketDetailView` |
| Classe view custom | PascalCase + azione + `View` | `TicketAssignView` |
| URL pattern | kebab-case | `ticket-list`, `ticket-detail` |
| URL path | kebab-case con `/` finale | `tickets/`, `tickets/<int:pk>/` |
| Metodo service | snake_case verbo | `get_list`, `create`, `update`, `delete` |
| Task Celery | snake_case verbo | `send_ticket_notification` |
| Signal handler | `on_` + modello + evento | `on_ticket_created` |
| Test class | PascalCase + `Test` | `TicketServiceTest` |
| Test method | `test_` + descrizione | `test_create_returns_201` |

---

## 7. Regole API

### Struttura URL

```
/api/{nome-plugin}/{risorsa}/              → lista + creazione
/api/{nome-plugin}/{risorsa}/<pk>/         → dettaglio + update + delete
/api/{nome-plugin}/{risorsa}/<pk>/{azione}/ → azioni custom
```

Esempi:

```
GET    /api/ticket-manager/tickets/           → lista ticket
POST   /api/ticket-manager/tickets/           → crea ticket
GET    /api/ticket-manager/tickets/42/        → dettaglio ticket 42
PATCH  /api/ticket-manager/tickets/42/        → aggiorna ticket 42
DELETE /api/ticket-manager/tickets/42/        → elimina ticket 42
POST   /api/ticket-manager/tickets/42/assign/ → azione custom
```

### Metodi HTTP

| Operazione | Metodo | Status risposta successo |
|---|---|---|
| Lista | GET | 200 |
| Dettaglio | GET | 200 |
| Creazione | POST | 201 |
| Aggiornamento parziale | PATCH | 200 |
| Aggiornamento completo | PUT | 200 |
| Eliminazione | DELETE | 204 |
| Azione custom | POST | 200 |

### Formato risposta errori

Tutti gli errori seguono questo formato:

```json
{
    "detail": "Messaggio di errore leggibile."
}
```

oppure per errori di validazione:

```json
{
    "campo": ["Messaggio di errore per questo campo."]
}
```

---

## 8. Regole Models

- Ogni modello DEVE avere `created_at = DateTimeField(auto_now_add=True)`
- Ogni modello DEVE avere `updated_at = DateTimeField(auto_now=True)`
- Ogni modello DEVE avere `__str__` che ritorna una stringa significativa
- Ogni modello DEVE avere `class Meta` con `ordering` e `verbose_name`
- I campi di stato usano SEMPRE `TextChoices` definiti in `constants.py`
- Le FK verso `User` usano `related_name` esplicito e descrittivo
- Non usare `null=True` su campi stringa — usare `blank=True` e default `""`
- Usare `on_delete=models.PROTECT` quando la cancellazione del parent
  non deve essere consentita se esistono oggetti collegati

---

## 9. Regole Services

- Tutti i metodi sono `@staticmethod`
- La classe non viene mai istanziata
- Ogni metodo ha un docstring
- Un metodo service fa UNA cosa sola
- I metodi che non trovano un oggetto lanciano `Http404` o eccezione esplicita,
  mai ritornano `None`
- La logica di permessi sull'oggetto specifico sta nel service, non nella view
- Le notifiche (email, task Celery) vengono chiamate dal service dopo
  l'operazione principale, mai dalla view

---

## 10. Regole Tests

- I test usano `django.test.TestCase`
- Le view si testano con `rest_framework.test.APIClient`
- Ogni test è indipendente — non dipende dall'ordine di esecuzione
- `setUp` crea i dati minimi necessari per i test della classe
- Il nome del metodo di test descrive esattamente cosa si sta testando
- Testare sempre il caso di errore oltre al caso di successo

Test minimi obbligatori per ogni view:
- Risposta `401` senza autenticazione
- Risposta corretta con autenticazione valida
- Risposta `404` con pk inesistente (per detail views)
- Risposta `400` con dati non validi (per POST/PATCH)

---

## 11. Checklist prima di un commit

Prima di committare codice relativo a un plugin, verificare:

**Struttura**
- [ ] Tutti i file obbligatori esistono
- [ ] `apps.py` ha `app_name` e `verbose_name` corretti
- [ ] Le migrations sono state generate e sono incluse nel commit

**Models**
- [ ] Ogni modello ha `created_at`, `updated_at`, `__str__`, `Meta`
- [ ] Nessun campo stringa usa `null=True`
- [ ] Le FK hanno `related_name` esplicito

**API**
- [ ] Ogni view ha `permission_classes` esplicito
- [ ] Le views non contengono logica di business
- [ ] Gli URL seguono la convenzione kebab-case con `/` finale
- [ ] `app_name` è definito in `urls.py`

**Services**
- [ ] Tutti i metodi sono `@staticmethod`
- [ ] Ogni metodo ha un docstring
- [ ] Nessun metodo ritorna `None` silenziosamente in caso di errore

**Admin**
- [ ] Ogni modello è registrato in admin
- [ ] `list_display` include almeno `id` e `created_at`

**Tests**
- [ ] I file di test esistono anche se i metodi sono ancora vuoti
- [ ] Nessun test dipende dall'ordine di esecuzione
