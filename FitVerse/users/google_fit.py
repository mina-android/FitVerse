# users/google_fit.py
import requests
import time

FIT_BASE_URL = "https://www.googleapis.com/fitness/v1/users/me"

def get_headers(access_token):
    return {"Authorization": f"Bearer {access_token}"}

def get_now_and_midnight():
    now_ms      = int(time.time() * 1000)
    midnight_ms = now_ms - (now_ms % 86400000)
    return now_ms, midnight_ms


def get_steps(access_token):
    now_ms, midnight_ms = get_now_and_midnight()
    response = requests.post(
        f"{FIT_BASE_URL}/dataset:aggregate",
        headers=get_headers(access_token),
        json={
            "aggregateBy": [{"dataTypeName": "com.google.step_count.delta"}],
            "bucketByTime": {"durationMillis": 86400000},
            "startTimeMillis": midnight_ms,
            "endTimeMillis": now_ms,
        }
    )
    try:
        return response.json()['bucket'][0]['dataset'][0]['point'][0]['value'][0]['intVal']
    except (IndexError, KeyError):
        return 0


def get_heart_rate(access_token):
    now_ns     = int(time.time() * 1e9)
    day_ago_ns = now_ns - int(86400 * 1e9)
    response   = requests.get(
        f"{FIT_BASE_URL}/dataSources/derived:com.google.heart_rate.bpm:com.google.android.gms:merge_heart_rate_bpm/datasets/{day_ago_ns}-{now_ns}",
        headers=get_headers(access_token),
    )
    try:
        return round(response.json()['point'][-1]['value'][0]['fpVal'], 1)
    except (IndexError, KeyError):
        return None


def get_sleep(access_token):
    now_ms, midnight_ms = get_now_and_midnight()
    response = requests.post(
        f"{FIT_BASE_URL}/dataset:aggregate",
        headers=get_headers(access_token),
        json={
            "aggregateBy": [{"dataTypeName": "com.google.sleep.segment"}],
            "bucketByTime": {"durationMillis": 86400000},
            "startTimeMillis": midnight_ms - 86400000,  # yesterday
            "endTimeMillis": midnight_ms,
        }
    )
    try:
        points  = response.json()['bucket'][0]['dataset'][0]['point']
        minutes = sum(
            (int(p['endTimeNanos']) - int(p['startTimeNanos'])) / 6e10
            for p in points if p['value'][0]['intVal'] in [4, 5, 6]  # light, deep, REM
        )
        return round(minutes / 60, 1)
    except (IndexError, KeyError):
        return None


def get_physical_activity(access_token):
    now_ms, midnight_ms = get_now_and_midnight()
    response = requests.post(
        f"{FIT_BASE_URL}/dataset:aggregate",
        headers=get_headers(access_token),
        json={
            "aggregateBy": [{"dataTypeName": "com.google.active_minutes"}],
            "bucketByTime": {"durationMillis": 86400000},
            "startTimeMillis": midnight_ms,
            "endTimeMillis": now_ms,
        }
    )
    try:
        return response.json()['bucket'][0]['dataset'][0]['point'][0]['value'][0]['intVal']
    except (IndexError, KeyError):
        return 0