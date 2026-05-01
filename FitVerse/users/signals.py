# users/signals.py
from django.dispatch import receiver
from allauth.socialaccount.signals import social_account_updated, pre_social_login
from allauth.socialaccount.models import SocialToken
from django.utils import timezone
from datetime import timedelta
from .models import UserProfile


def save_google_token(sociallogin, **kwargs):
    """Runs after Google login — copies the token into UserProfile."""
    user = sociallogin.user

    if not user.pk:
        return  # user not saved yet

    try:
        token = SocialToken.objects.get(
            account=sociallogin.account,
            account__provider='google'
        )

        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.google_access_token  = token.token
        profile.google_refresh_token = token.token_secret  # allauth stores refresh here
        profile.token_expires_at     = token.expires_at
        profile.save()

    except SocialToken.DoesNotExist:
        pass


# Fires on first login
pre_social_login.connect(save_google_token)

# Fires on subsequent logins (token refresh)
social_account_updated.connect(save_google_token)