from django.shortcuts import render, redirect
from django.contrib.auth import logout
# Create your views here.
from django.contrib.auth.decorators import login_required
from .models import UserProfile
from .forms import UserProfileForm

def home(request):
    return render(request, "home.html")

def logout_view(request):
    logout(request)
    return redirect("/")

from django.contrib.auth.decorators import login_required
from .models import UserProfile
from .forms import UserProfileForm
from allauth.socialaccount.models import SocialToken, SocialAccount
from .google_fit import get_steps, get_heart_rate, get_sleep, get_physical_activity


@login_required
def post_login_redirect(request):
    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    if profile.is_complete():
        return redirect('dashboard')       # ← goes to dashboard now
    return redirect('onboarding')


@login_required
def onboarding(request):
    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    if request.method == 'POST':
        form = UserProfileForm(request.POST, instance=profile)
        if form.is_valid():
            form.save()
            return redirect('dashboard')   # ← after onboarding → dashboard
    else:
        form = UserProfileForm(instance=profile)
    return render(request, 'users/onboarding.html', {'form': form})


@login_required
def dashboard(request):
    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    if not profile.is_complete():
        return redirect('onboarding')

    # Placeholder fit data — replace with real API calls in Step 3+
    fit_data = {
        'steps':             0,
        'blood_pressure':    '--/--',
        'heart_rate':        '--',
        'sleep_hours':       '--',
        'physical_activity': '--',
    }

    return render(request, 'users/dashboard.html', {
        'profile':  profile,
        'fit_data': fit_data,
    })


@login_required
def account(request):
    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    if request.method == 'POST':
        form = UserProfileForm(request.POST, instance=profile)
        if form.is_valid():
            form.save()
            return redirect('account')
    else:
        form = UserProfileForm(instance=profile)
    return render(request, 'users/account.html', {
        'form':    form,
        'profile': profile,
        'user':    request.user,
    })


@login_required
def ai_chat(request):
    return render(request, 'users/ai_chat.html')

@login_required
def dashboard(request):
    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    if not profile.is_complete():
        return redirect('onboarding')

    # Get token from allauth
    try:
        account      = SocialAccount.objects.get(user=request.user, provider='google')
        token        = SocialToken.objects.get(account=account)
        access_token = token.token
    except Exception:
        access_token = None

    fit_data = {
        'steps':             get_steps(access_token)            if access_token else '--',
        'heart_rate':        get_heart_rate(access_token)       if access_token else '--',
        'sleep_hours':       get_sleep(access_token)            if access_token else '--',
        'physical_activity': get_physical_activity(access_token) if access_token else '--',
        'blood_pressure':    '--',   # not available in Google Fit API
    }

    return render(request, 'users/dashboard.html', {
        'profile':  profile,
        'fit_data': fit_data,
    })