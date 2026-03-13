import os

AUTH_USER_MODEL = "user_manager.User"

AUTH_MODE = os.getenv("AUTH_MODE", "django").lower()  # "django" | "keycloak"

AUTHENTICATION_BACKENDS = (
    "django.contrib.auth.backends.ModelBackend",
    "allauth.account.auth_backends.AuthenticationBackend",
)

LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/"

ACCOUNT_LOGIN_METHODS = {"username", "email"}
ACCOUNT_SIGNUP_FIELDS = ["email*", "username*", "password1*", "password2*"]
ACCOUNT_EMAIL_VERIFICATION = "mandatory"

# ---------------------------------------------------------------------------
# Allauth headless (JWT strategy) — only when AUTH_MODE=django
# Verify with: pip show django-allauth and changelog for HEADLESS_JWT_* names
# ---------------------------------------------------------------------------
if AUTH_MODE == "django":
    HEADLESS_TOKEN_STRATEGY = "allauth.headless.tokens.strategies.jwt.JWTTokenStrategy"
    HEADLESS_JWT_ALGORITHM = os.getenv("HEADLESS_JWT_ALGORITHM", "HS256")
    HEADLESS_JWT_PRIVATE_KEY = os.getenv("HEADLESS_JWT_PRIVATE_KEY", "") or os.environ.get("SECRET_KEY", "")
    HEADLESS_JWT_ACCESS_TOKEN_EXPIRES_IN = int(os.getenv("HEADLESS_JWT_ACCESS_TOKEN_EXPIRES_IN", "900"))  # 15 min
    HEADLESS_JWT_REFRESH_TOKEN_EXPIRES_IN = int(os.getenv("HEADLESS_JWT_REFRESH_TOKEN_EXPIRES_IN", "86400"))  # 1 day
    HEADLESS_JWT_ROTATE_REFRESH_TOKEN = os.getenv("HEADLESS_JWT_ROTATE_REFRESH_TOKEN", "true").lower() in ("1", "true", "yes")
    HEADLESS_FRONTEND_URLS = {
        "account_confirm_email": os.getenv("HEADLESS_URL_ACCOUNT_CONFIRM_EMAIL", "http://localhost:4200/account/verify-email/{key}"),
        "account_reset_password": os.getenv("HEADLESS_URL_ACCOUNT_RESET_PASSWORD", "http://localhost:4200/account/password/reset"),
        "account_reset_password_from_key": os.getenv("HEADLESS_URL_ACCOUNT_RESET_PASSWORD_FROM_KEY", "http://localhost:4200/account/password/reset/key/{key}"),
        "account_signup": os.getenv("HEADLESS_URL_ACCOUNT_SIGNUP", "http://localhost:4200/signup"),
    }

# DRF defaults per mode
if AUTH_MODE == "keycloak":
    REST_FRAMEWORK = {
        "DEFAULT_AUTHENTICATION_CLASSES": [
            "base_modules.user_manager.auth_keycloak.KeycloakJWTAuthentication",
        ],
        "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    }
else:
    # django mode: use allauth headless JWT for API (access token from headless login/refresh)
    REST_FRAMEWORK = {
        "DEFAULT_AUTHENTICATION_CLASSES": [
            "allauth.headless.contrib.rest_framework.authentication.JWTTokenAuthentication",
        ],
        "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    }
