"""
URL configuration for mixtum_core project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings

from base_modules.celery.views import flower_auth

urlpatterns = [
    path('admin/', admin.site.urls),

    # Celery Flower
    path("flower-auth/", flower_auth, name="flower-auth"),

    # Auth and Users
    path('api/v1/accounts/', include('allauth.urls')),
    path('api/v1/users/', include('base_modules.user_manager.urls')),

    # Attachments
    path('api/attachments/', include(('base_modules.attachment.urls', 'attachment'), namespace='attachment')),

    # Links
    path('api/links/', include(('base_modules.links.urls', 'links'), namespace='links')),

    # Plugin Example (template di riferimento)
    path('api/plugin-example/', include(('plugins.plugin_example.urls', 'plugin_example'), namespace='plugin_example')),

    # Workspace
    path('api/workspace/', include('base_modules.workspace.urls')),

    # Branding
    path('api/branding/', include('base_modules.branding.urls')),

    # External Integrations
    path('api/slack/', include(('base_modules.integrations.notifications.urls', 'notifications'), namespace='slack')),
    path('api/n8n/', include(('base_modules.integrations.automation.urls', 'automation'), namespace='n8n')),
    # WhatsApp (Twilio) — messaging
    path('api/whatsapp/', include(('base_modules.integrations.messaging.urls', 'messaging'), namespace='twilio')),
]


if getattr(settings, 'AUTH_MODE', 'django') == 'keycloak':
    urlpatterns += [path('oidc/', include('mozilla_django_oidc.urls'))]
