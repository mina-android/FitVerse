# users/forms.py
from django import forms
from .models import UserProfile

class UserProfileForm(forms.ModelForm):
    class Meta:
        model = UserProfile
        fields = ['age', 'height', 'weight', 'workout_level']
        widgets = {
            'age': forms.NumberInput(attrs={'placeholder': 'Your age', 'min': 1, 'max': 120}),
            'height': forms.NumberInput(attrs={'placeholder': 'Height in cm'}),
            'weight': forms.NumberInput(attrs={'placeholder': 'Weight in kg'}),
            'workout_level': forms.RadioSelect(),
        }