from django.contrib.auth import views as auth_views
from django.urls import path, include
from . import views

urlpatterns = [
    path('',            views.post_login_redirect, name='post_login_redirect'),
    path('onboarding/', views.onboarding,          name='onboarding'),
    path('dashboard/',  views.dashboard,            name='dashboard'),
    path('account/',    views.account,              name='account'),
    path('ai-chat/',    views.ai_chat,              name='ai_chat'),
    
]