# Mixtum — Plugin Development Standard

This document defines the mandatory standard for creating and developing plugins in the Mixtum framework. It applies to all derived products (ED Ticket, Fiscally, custom projects). It is intended for human developers and AI systems that generate code automatically.

---

## Index

1. [Required file structure](#1-required-file-structure)
2. [Optional files](#2-optional-files)
3. [General rules](#3-general-rules)
4. [Skeleton of each required file](#4-skeleton-of-each-required-file)
5. [Skeleton of optional files](#5-skeleton-of-optional-files)
6. [Naming conventions](#6-naming-conventions)
7. [API rules](#7-api-rules)
8. [Models rules](#8-models-rules)
9. [Services rules](#9-services-rules)
10. [Tests rules](#10-tests-rules)
11. [Pre-commit checklist](#11-pre-commit-checklist)

---

## 1. Required file structure

Each plugin MUST have exactly this structure. No required file can be omitted, even if it initially contains only an empty skeleton.

```
plugins/
└── plugin_name/
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

## 2. Optional files

The following files should be added ONLY when actually needed.
Do not create empty optional files.

| File | When to add it |
|---|---|
| `permissions.py` | The plugin has access logic specific to roles or ownership |
| `signals.py` | The plugin reacts to events of other models via Django signals |
| `tasks.py` | The plugin has asynchronous operations via Celery |
| `filters.py` | List views have complex query filters (beyond basic parameters) |
| `pagination.py` | The plugin uses pagination different from the global one |
| `managers.py` | Models have complex and reusable queryset logic |
| `constants.py` | The plugin has constants shared across multiple files |
| `exceptions.py` | The plugin has custom exceptions |

---

## 3. General rules

### 3.1 Allowed dependencies

A plugin MAY import from:
- `base_modules.*` — any Mixtum base module
- `django.*` — Django framework
- `rest_framework.*` — Django REST Framework
- third-party Python libraries installed in `requirements.txt`

A plugin MAY NOT import from:
- other plugins (`plugins.*`)

If two plugins need to communicate, use Django signals or a service layer
that accepts already-resolved objects as parameters.

```python
# FORBIDDEN
from plugins.project_manager.models import Project  # ❌

# CORRECT — the project is passed from the outside
class TicketService:
    @staticmethod
    def create(data, user, project):  # ✅ project comes from the view
        ...
```

### 3.2 Business logic

- `views.py` MUST NOT contain business logic. They only call services.
- `models.py` MUST NOT contain business logic. They only contain data structure
  and simple utility methods (e.g. `__str__`, `get_absolute_url`, properties).
- All business logic lives in `services.py`.

### 3.3 Database access

- Views MUST NOT perform direct queries. They use services.
- Services use model managers or explicit querysets.
- Complex and reusable queries live in `managers.py`.

---

## 4. Skeleton of each required file

Replace `plugin_name` with the real plugin name in snake_case.
Replace `PluginName` with the name in PascalCase.

---

### `__init__.py`

```python
# Leave empty
```

---

### `apps.py`

```python
from django.apps import AppConfig


class PluginNameConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "plugins.plugin_name"
    verbose_name = "Plugin Name"

    def ready(self):
        # Import signals here if the plugin uses them
        # import plugins.plugin_name.signals  # noqa
        pass
```

---

### `models.py`

```python
from django.db import models
from base_modules.user_manager.models import User
from base_modules.workspace.models import Workspace


class ModelName(models.Model):
    """
    Short description of the model.
    """
    workspace = models.ForeignKey(
        Workspace,
        on_delete=models.CASCADE,
        related_name="model_name_set",
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="model_name_created",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Model Name"
        verbose_name_plural = "Model Names"

    def __str__(self):
        return f"{self.__class__.__name__} #{self.pk}"
```

**Models rules:**
- Every model MUST have `created_at` and `updated_at`.
- Every model MUST have `__str__`.
- Every model MUST have `Meta` with at least `ordering` and `verbose_name`.
- Models tied to a workspace MUST have an FK to `Workspace`.

---

### `serializers.py`

```python
from rest_framework import serializers
from .models import ModelName


class ModelNameSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModelName
        fields = [
            "id",
            "workspace",
            "created_by",
            "created_at",
            "updated_at",
            # add specific fields
        ]
        read_only_fields = ["id", "created_at", "updated_at", "created_by"]


class ModelNameWriteSerializer(serializers.ModelSerializer):
    """
    Serializer used for create and update.
    Separate from the read serializer for explicit control over writable fields.
    """
    class Meta:
        model = ModelName
        fields = [
            # only the fields that the user can write
        ]
```

**Serializers rules:**
- Use separate serializers for read and write when the fields differ.
- `id`, `created_at`, `updated_at`, `created_by` are always `read_only`.
- Do not use `fields = "__all__"`.

---

### `views.py`

```python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from .models import ModelName
from .serializers import ModelNameSerializer, ModelNameWriteSerializer
from .services import ModelNameService


class ModelNameListView(APIView):
    """
    GET  /api/plugin-name/model-name/        → list
    POST /api/plugin-name/model-name/        → create
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        workspace = request.user.current_workspace
        items = ModelNameService.get_list(workspace=workspace)
        serializer = ModelNameSerializer(items, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = ModelNameWriteSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        item = ModelNameService.create(
            data=serializer.validated_data,
            user=request.user,
        )
        return Response(ModelNameSerializer(item).data, status=status.HTTP_201_CREATED)


class ModelNameDetailView(APIView):
    """
    GET    /api/plugin-name/model-name/<pk>/ → detail
    PATCH  /api/plugin-name/model-name/<pk>/ → update
    DELETE /api/plugin-name/model-name/<pk>/ → delete
    """
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        return ModelNameService.get_by_id(pk=pk, user=user)

    def get(self, request, pk):
        item = self.get_object(pk, request.user)
        return Response(ModelNameSerializer(item).data)

    def patch(self, request, pk):
        item = self.get_object(pk, request.user)
        serializer = ModelNameWriteSerializer(item, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        item = ModelNameService.update(
            instance=item,
            data=serializer.validated_data,
            user=request.user,
        )
        return Response(ModelNameSerializer(item).data)

    def delete(self, request, pk):
        item = self.get_object(pk, request.user)
        ModelNameService.delete(instance=item, user=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)
```

**Views rules:**
- Every view MUST have explicit `permission_classes`.
- Views MUST NOT contain logic. They delegate everything to services.
- Always use DRF `status.*`, never hardcoded numbers (e.g. `200`, `404`).
- Every view class MUST have a docstring with the HTTP methods and URLs it handles.

---

### `urls.py`

```python
from django.urls import path
from . import views

app_name = "plugin_name"

urlpatterns = [
    path(
        "model-name/",
        views.ModelNameListView.as_view(),
        name="model-name-list",
    ),
    path(
        "model-name/<int:pk>/",
        views.ModelNameDetailView.as_view(),
        name="model-name-detail",
    ),
]
```

**URLs rules:**
- `app_name` is mandatory.
- Every URL MUST have a `name`.
- URLs use kebab-case (`model-name`, not `modelName` nor `model_name`).
- URLs always end with `/`.

---

### `admin.py`

```python
from django.contrib import admin
from .models import ModelName


@admin.register(ModelName)
class ModelNameAdmin(admin.ModelAdmin):
    list_display = ["id", "workspace", "created_by", "created_at"]
    list_filter = ["workspace", "created_at"]
    search_fields = ["id"]
    readonly_fields = ["created_at", "updated_at"]
```

**Admin rules:**
- Every model MUST be registered in admin.
- `list_display` MUST include at least `id` and `created_at`.
- `readonly_fields` MUST include `created_at` and `updated_at`.

---

### `services.py`

```python
from django.shortcuts import get_object_or_404
from .models import ModelName


class ModelNameService:
    """
    Business logic for ModelName.
    All methods are static — the class is used as a namespace, not instantiated.
    """

    @staticmethod
    def get_list(workspace):
        """
        Return all objects in the workspace.
        """
        return ModelName.objects.filter(workspace=workspace)

    @staticmethod
    def get_by_id(pk, user):
        """
        Return a single object. Raise 404 if not found.
        Check any access permissions to the object here.
        """
        return get_object_or_404(
            ModelName,
            pk=pk,
            workspace=user.current_workspace,
        )

    @staticmethod
    def create(data, user):
        """
        Create a new object.
        """
        return ModelName.objects.create(
            **data,
            created_by=user,
            workspace=user.current_workspace,
        )

    @staticmethod
    def update(instance, data, user):
        """
        Update an existing object.
        """
        for attr, value in data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance

    @staticmethod
    def delete(instance, user):
        """
        Delete an object.
        """
        instance.delete()
```

**Services rules:**
- All methods are `@staticmethod`.
- The class is NOT instantiated — it is a namespace for logic.
- Every method MUST have a docstring, even minimal.
- Object permission logic (ownership, role) lives here, not in the view.
- Methods that fail for business-logic reasons raise explicit exceptions,
  they do not silently return `None`.

---

### `migrations/__init__.py`

```python
# Leave empty
```

---

### `tests/__init__.py`

```python
# Leave empty
```

---

### `tests/test_models.py`

```python
from django.test import TestCase
from django.contrib.auth import get_user_model

User = get_user_model()


class ModelNameModelTest(TestCase):
    """
    Tests for the ModelName model.
    """

    def setUp(self):
        # Setup data common to all tests in this class
        pass

    def test_str(self):
        # Verify that __str__ returns a meaningful value
        pass

    def test_created_at_auto_set(self):
        # Verify that created_at is set automatically
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


class ModelNameListViewTest(TestCase):
    """
    Tests for ModelNameListView.
    """

    def setUp(self):
        self.client = APIClient()
        # self.user = User.objects.create_user(...)
        # self.client.force_authenticate(user=self.user)

    def test_list_requires_authentication(self):
        # Verify that the view returns 401 without authentication
        pass

    def test_list_returns_200(self):
        # Verify that the view returns 200 with an authenticated user
        pass

    def test_create_returns_201(self):
        # Verify that create returns 201
        pass
```

---

### `tests/test_services.py`

```python
from django.test import TestCase


class ModelNameServiceTest(TestCase):
    """
    Tests for ModelNameService.
    """

    def setUp(self):
        pass

    def test_create(self):
        # Verify that create() returns a valid object
        pass

    def test_get_by_id_raises_404_if_not_found(self):
        # Verify that get_by_id() raises 404 if the object does not exist
        pass
```

---

## 5. Skeleton of optional files

---

### `permissions.py`

```python
from rest_framework.permissions import BasePermission


class IsWorkspaceMember(BasePermission):
    """
    Allows access only to members of the current workspace.
    """
    message = "You do not have permission to access this resource."

    def has_permission(self, request, view):
        # view-level permission logic
        return True

    def has_object_permission(self, request, view, obj):
        # object-level permission logic
        return obj.workspace == request.user.current_workspace
```

---

### `signals.py`

```python
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import ModelName


@receiver(post_save, sender=ModelName)
def on_model_name_saved(sender, instance, created, **kwargs):
    """
    Executed after saving ModelName.
    """
    if created:
        pass  # logic for new objects
    else:
        pass  # logic for updated objects


@receiver(post_delete, sender=ModelName)
def on_model_name_deleted(sender, instance, **kwargs):
    """
    Executed after deleting ModelName.
    """
    pass
```

**Note:** signals must be imported in `apps.py` in the `ready()` method.

```python
# apps.py
def ready(self):
    import plugins.plugin_name.signals  # noqa
```

---

### `tasks.py`

```python
from mixtum_core.celery import app


@app.task(bind=True, max_retries=3)
def task_name(self, object_id):
    """
    Task description.
    bind=True allows access to self for retry.
    max_retries=3 is the recommended default.
    """
    try:
        # task logic
        pass
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60)
```

---

### `filters.py`

```python
from django.db.models import Q


class ModelNameFilter:
    """
    Filter logic for ModelName.
    Used in services, not directly in views.
    """

    @staticmethod
    def apply(queryset, params):
        search = params.get("search")
        if search:
            queryset = queryset.filter(
                Q(field_one__icontains=search) |
                Q(field_two__icontains=search)
            )
        return queryset
```

---

### `managers.py`

```python
from django.db import models


class ModelNameQuerySet(models.QuerySet):

    def active(self):
        return self.filter(active=True)

    def for_workspace(self, workspace):
        return self.filter(workspace=workspace)


class ModelNameManager(models.Manager):

    def get_queryset(self):
        return ModelNameQuerySet(self.model, using=self._db)

    def active(self):
        return self.get_queryset().active()

    def for_workspace(self, workspace):
        return self.get_queryset().for_workspace(workspace)
```

Used in the model:

```python
class ModelName(models.Model):
    objects = ModelNameManager()
    ...
```

---

### `constants.py`

```python
class ModelNameStatus(models.TextChoices):
    DRAFT = "draft", "Draft"
    ACTIVE = "active", "Active"
    ARCHIVED = "archived", "Archived"
```

---

### `exceptions.py`

```python
from rest_framework.exceptions import APIException
from rest_framework import status


class ModelNameNotFound(APIException):
    status_code = status.HTTP_404_NOT_FOUND
    default_detail = "Object not found."
    default_code = "not_found"


class OperationNotAllowed(APIException):
    status_code = status.HTTP_403_FORBIDDEN
    default_detail = "Operation not allowed."
    default_code = "forbidden"
```

---

## 6. Naming conventions

| Element | Convention | Example |
|---|---|---|
| Plugin folder | snake_case | `ticket_manager` |
| Model class | PascalCase | `Ticket`, `TicketMessage` |
| Service class | PascalCase + `Service` | `TicketService` |
| Read serializer class | PascalCase + `Serializer` | `TicketSerializer` |
| Write serializer class | PascalCase + `WriteSerializer` | `TicketWriteSerializer` |
| List view class | PascalCase + `ListView` | `TicketListView` |
| Detail view class | PascalCase + `DetailView` | `TicketDetailView` |
| Custom view class | PascalCase + action + `View` | `TicketAssignView` |
| URL name | kebab-case | `ticket-list`, `ticket-detail` |
| URL path | kebab-case with trailing `/` | `tickets/`, `tickets/<int:pk>/` |
| Service method | snake_case verb | `get_list`, `create`, `update`, `delete` |
| Celery task | snake_case verb | `send_ticket_notification` |
| Signal handler | `on_` + model + event | `on_ticket_created` |
| Test class | PascalCase + `Test` | `TicketServiceTest` |
| Test method | `test_` + description | `test_create_returns_201` |

---

## 7. API rules

### URL structure

```
/api/{plugin-name}/{resource}/               → list + create
/api/{plugin-name}/{resource}/<pk>/          → detail + update + delete
/api/{plugin-name}/{resource}/<pk>/{action}/  → custom actions
```

Examples:

```
GET    /api/ticket-manager/tickets/           → list tickets
POST   /api/ticket-manager/tickets/           → create ticket
GET    /api/ticket-manager/tickets/42/        → ticket 42 detail
PATCH  /api/ticket-manager/tickets/42/        → update ticket 42
DELETE /api/ticket-manager/tickets/42/        → delete ticket 42
POST   /api/ticket-manager/tickets/42/assign/ → custom action
```

### HTTP methods

| Operation | Method | Success status code |
|---|---|---|
| List | GET | 200 |
| Detail | GET | 200 |
| Create | POST | 201 |
| Partial update | PATCH | 200 |
| Full update | PUT | 200 |
| Delete | DELETE | 204 |
| Custom action | POST | 200 |

### Error response format

All errors follow this format:

```json
{
    "detail": "Human-readable error message."
}
```

or for validation errors:

```json
{
    "field": ["Error message for this field."]
}
```

---

## 8. Models rules

- Every model MUST have `created_at = DateTimeField(auto_now_add=True)`
- Every model MUST have `updated_at = DateTimeField(auto_now=True)`
- Every model MUST have `__str__` that returns a meaningful string
- Every model MUST have `class Meta` with `ordering` and `verbose_name`
- State fields ALWAYS use `TextChoices` defined in `constants.py`
- FKs to `User` use an explicit and descriptive `related_name`
- Do not use `null=True` on string fields — use `blank=True` and default `""`
- Use `on_delete=models.PROTECT` when deletion of the parent
  must not be allowed if related objects exist

---

## 9. Services rules

- All methods are `@staticmethod`
- The class is never instantiated
- Every method has a docstring
- A service method does ONE single thing
- Methods that do not find an object raise `Http404` or an explicit exception,
  never silently return `None`
- Object-specific permission logic lives in the service, not in the view
- Notifications (emails, Celery tasks) are triggered by the service after
  the main operation, never from the view

---

## 10. Tests rules

- Tests use `django.test.TestCase`
- Views are tested with `rest_framework.test.APIClient`
- Each test is independent — it does not depend on execution order
- `setUp` creates the minimum data required for the class tests
- The test method name describes exactly what is being tested
- Always test the error case as well as the success case

Minimum mandatory tests for each view:
- Response `401` without authentication
- Correct response with valid authentication
- Response `404` with non-existent pk (for detail views)
- Response `400` with invalid data (for POST/PATCH)

---

## 11. Pre-commit checklist

Before committing plugin-related code, verify:

**Structure**
- [ ] All required files exist
- [ ] `apps.py` has correct `app_name` and `verbose_name`
- [ ] Migrations have been generated and are included in the commit

**Models**
- [ ] Every model has `created_at`, `updated_at`, `__str__`, `Meta`
- [ ] No string field uses `null=True`
- [ ] FKs have an explicit `related_name`

**API**
- [ ] Every view has explicit `permission_classes`
- [ ] Views do not contain business logic
- [ ] URLs follow kebab-case convention with trailing `/`
- [ ] `app_name` is defined in `urls.py`

**Services**
- [ ] All methods are `@staticmethod`
- [ ] Every method has a docstring
- [ ] No method silently returns `None` in case of error

**Admin**
- [ ] Every model is registered in admin
- [ ] `list_display` includes at least `id` and `created_at`

**Tests**
- [ ] Test files exist even if methods are still empty
- [ ] No test depends on execution order
