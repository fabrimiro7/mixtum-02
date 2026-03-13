"""
Headless auth wrapper: proxy to allauth headless API and set refresh token
in httpOnly cookie; return only access token in body (Opzione B - enterprise).
"""
import json
import os
from types import SimpleNamespace

from django.conf import settings
from django.http import HttpRequest, JsonResponse
from django.urls import resolve, Resolver404
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

# Cookie name for refresh token (httpOnly, not readable by JS)
REFRESH_COOKIE_NAME = os.getenv("HEADLESS_REFRESH_COOKIE_NAME", "refresh_token")
REFRESH_COOKIE_MAX_AGE = int(os.getenv("HEADLESS_JWT_REFRESH_TOKEN_EXPIRES_IN", "86400"))
REFRESH_COOKIE_HTTPONLY = True
REFRESH_COOKIE_SECURE = getattr(settings, "SESSION_COOKIE_SECURE", False)
REFRESH_COOKIE_SAMESITE = os.getenv("HEADLESS_REFRESH_COOKIE_SAMESITE", "Lax")


def _set_refresh_cookie(response: Response, refresh_token: str) -> None:
    response.set_cookie(
        REFRESH_COOKIE_NAME,
        refresh_token,
        max_age=REFRESH_COOKIE_MAX_AGE,
        httponly=REFRESH_COOKIE_HTTPONLY,
        secure=REFRESH_COOKIE_SECURE,
        samesite=REFRESH_COOKIE_SAMESITE,
        path="/",
    )


def _clear_refresh_cookie(response: Response) -> None:
    response.delete_cookie(REFRESH_COOKIE_NAME, path="/")


def _copy_request_for_allauth(original: HttpRequest, path: str, body: dict) -> HttpRequest:
    """Build a new request with the given path and JSON body for calling allauth headless."""
    from django.test import RequestFactory

    factory = RequestFactory()
    body_bytes = json.dumps(body).encode("utf-8") if body else b""
    req = factory.post(path, body_bytes, content_type="application/json")

    # Propaga sessione/utente dalla richiesta originale
    req.session = original.session
    req.user = original.user

    # Simula AccountMiddleware: allauth.headless si aspetta request.allauth
    # per poter impostare request.allauth.headless.*
    req.allauth = SimpleNamespace()

    return req


class HeadlessLoginWrapperView(APIView):
    """Wrapper: proxy POST to allauth headless auth/login, set refresh in httpOnly cookie, return only access_token."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        if getattr(settings, "AUTH_MODE", "django") != "django":
            return Response(
                {"detail": "Headless login only when AUTH_MODE=django."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            # Resolve allauth headless login view (app client)
            path = "/api/v1/accounts/_allauth/app/v1/auth/login"
            internal_req = _copy_request_for_allauth(request, path, request.data)
            match = resolve(path)
            login_view = match.func
            auth_response = login_view(internal_req)
        except (Resolver404, Exception) as e:
            return Response(
                {"detail": "Login failed.", "error": str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        if auth_response.status_code != 200:
            try:
                data = auth_response.json() if hasattr(auth_response, "json") else json.loads(auth_response.content)
            except Exception:
                data = {"detail": "Authentication failed"}
            return Response(data, status=auth_response.status_code)
        try:
            payload = auth_response.json() if hasattr(auth_response, "json") else json.loads(auth_response.content)
        except Exception:
            return Response({"detail": "Invalid response"}, status=status.HTTP_502_BAD_GATEWAY)
        meta = payload.get("meta") or {}
        access_token = meta.get("access_token")
        refresh_token = meta.get("refresh_token")
        if not access_token:
            return Response({"detail": "No access token in response"}, status=status.HTTP_502_BAD_GATEWAY)
        out = Response({
            "token": access_token,
            "access_token": access_token,
            "expires_in": getattr(settings, "HEADLESS_JWT_ACCESS_TOKEN_EXPIRES_IN", 900),
            "data": payload.get("data"),
            "message": "success",
        }, status=status.HTTP_200_OK)
        if refresh_token:
            _set_refresh_cookie(out, refresh_token)
        return out


class HeadlessRefreshWrapperView(APIView):
    """Wrapper: read refresh from cookie, proxy to allauth headless tokens/refresh, set new refresh in cookie, return only access_token."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        if getattr(settings, "AUTH_MODE", "django") != "django":
            return Response(
                {"detail": "Headless refresh only when AUTH_MODE=django."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        refresh_token = request.COOKIES.get(REFRESH_COOKIE_NAME)
        if not refresh_token:
            return Response({"detail": "Missing refresh token"}, status=status.HTTP_401_UNAUTHORIZED)
        try:
            path = "/api/v1/accounts/_allauth/app/v1/tokens/refresh"
            internal_req = _copy_request_for_allauth(request, path, {"refresh_token": refresh_token})
            match = resolve(path)
            refresh_view = match.func
            auth_response = refresh_view(internal_req)
        except (Resolver404, Exception) as e:
            return Response(
                {"detail": "Refresh failed.", "error": str(e)},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        if auth_response.status_code != 200:
            out = Response({"detail": "Invalid or expired refresh token"}, status=status.HTTP_401_UNAUTHORIZED)
            _clear_refresh_cookie(out)
            return out
        try:
            payload = auth_response.json() if hasattr(auth_response, "json") else json.loads(auth_response.content)
        except Exception:
            return Response({"detail": "Invalid response"}, status=status.HTTP_502_BAD_GATEWAY)
        data = payload.get("data") or payload
        access_token = data.get("access_token")
        next_refresh = data.get("refresh_token")
        if not access_token:
            return Response({"detail": "No access token"}, status=status.HTTP_502_BAD_GATEWAY)
        out = Response({
            "token": access_token,
            "access_token": access_token,
            "expires_in": getattr(settings, "HEADLESS_JWT_ACCESS_TOKEN_EXPIRES_IN", 900),
            "message": "success",
        }, status=status.HTTP_200_OK)
        if next_refresh:
            _set_refresh_cookie(out, next_refresh)
        else:
            _set_refresh_cookie(out, refresh_token)
        return out


class HeadlessSignupWrapperView(APIView):
    """
    Wrapper: proxy POST to allauth headless auth/signup.

    - In caso di flusso con verifica email obbligatoria restituisce lo stesso payload/status
      di allauth (tipicamente 200/201 + flows.verify_email.is_pending) senza settare cookie.
    - Se, in configurazioni particolari, allauth restituisce anche access/refresh token,
      normalizza la risposta come il login wrapper e imposta il refresh token in cookie httpOnly.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        if getattr(settings, "AUTH_MODE", "django") != "django":
            return Response(
                {"detail": "Headless signup only when AUTH_MODE=django."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Normalize payload: use email as username when username is missing (frontend may send only email/password)
        data = dict(request.data) if request.data else {}
        if not data.get("username") and data.get("email"):
            data["username"] = data["email"]
        try:
            path = "/api/v1/accounts/_allauth/app/v1/auth/signup"
            internal_req = _copy_request_for_allauth(request, path, data)
            match = resolve(path)
            signup_view = match.func
            auth_response = signup_view(internal_req)
        except (Resolver404, Exception) as e:
            return Response(
                {"detail": "Signup failed.", "error": str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        status_code = auth_response.status_code
        try:
            payload = auth_response.json() if hasattr(auth_response, "json") else json.loads(auth_response.content)
        except Exception:
            return Response({"detail": "Invalid response"}, status=status.HTTP_502_BAD_GATEWAY)

        # Se allauth non ha ancora emesso token (tipico con email_verification mandatory),
        # inoltra semplicemente payload al frontend che leggerà i flows.
        # Alcune versioni di allauth usano 401 per "verify_email pending": in quel caso
        # normalizziamo a 200 perché la registrazione è andata a buon fine.
        meta = payload.get("meta") or {}
        access_token = meta.get("access_token")
        refresh_token = meta.get("refresh_token")

        if not access_token:
            flows = (payload.get("data") or {}).get("flows") or []
            has_pending_verify = any(
                (f.get("id") == "verify_email" and f.get("is_pending")) for f in flows
            )
            if status_code == status.HTTP_401_UNAUTHORIZED and has_pending_verify:
                return Response(payload, status=status.HTTP_200_OK)
            return Response(payload, status=status_code)

        # Caso in cui signup autentica subito: normalizza come login wrapper
        out = Response(
            {
                "token": access_token,
                "access_token": access_token,
                "expires_in": getattr(settings, "HEADLESS_JWT_ACCESS_TOKEN_EXPIRES_IN", 900),
                "data": payload.get("data"),
                "message": "success",
            },
            status=status.HTTP_200_OK,
        )
        if refresh_token:
            _set_refresh_cookie(out, refresh_token)
        return out
