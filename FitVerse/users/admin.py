# users/admin.py
from django.contrib import admin
from .models import UserProfile

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'age', 'height', 'weight', 'workout_level', 'has_token']
    readonly_fields = ['google_access_token', 'google_refresh_token', 'token_expires_at']

    def has_token(self, obj):
        return bool(obj.google_access_token)
    has_token.boolean = True
    has_token.short_description = 'Token Saved?'