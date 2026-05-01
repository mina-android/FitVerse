from django.db import models

# Create your models here.
# users/models.py

from django.contrib.auth.models import User

class UserProfile(models.Model):
    LEVEL_CHOICES = [
        ('noob', 'Noob'),
        ('advance', 'Advance'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    age = models.PositiveIntegerField(null=True, blank=True)
    height = models.FloatField(null=True, blank=True, help_text="Height in cm")
    weight = models.FloatField(null=True, blank=True, help_text="Weight in kg")
    workout_level = models.CharField(max_length=10, choices=LEVEL_CHOICES, null=True, blank=True)
    google_access_token  = models.TextField(null=True, blank=True)
    google_refresh_token = models.TextField(null=True, blank=True)
    token_expires_at     = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.username}'s Profile"

    def is_complete(self):
        return all([self.age, self.height, self.weight, self.workout_level])