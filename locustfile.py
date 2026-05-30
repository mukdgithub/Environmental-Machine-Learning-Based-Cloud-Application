"""
Locust load test script for CloudEco Wildfire & Smoke Detection API.

Usage (web UI):
    locust -f locustfile.py --host http://35.223.85.181:31486

Usage (headless):
    locust -f locustfile.py --host http://35.223.85.181:31486 \
        --headless -u 10 -r 2 --run-time 60s
"""

import base64
import json
import os
import uuid

from locust import HttpUser, between, task

TEST_IMAGE_PATH = os.environ.get("TEST_IMAGE", "test_image.jpg")

with open(TEST_IMAGE_PATH, "rb") as f:
    ENCODED_IMAGE = base64.b64encode(f.read()).decode("utf-8")

HEADERS = {"Content-Type": "application/json"}


def make_payload() -> str:
    payload = {
        "uuid": str(uuid.uuid4()),
        "image": ENCODED_IMAGE,
    }
    return json.dumps(payload)


class CloudEcoUser(HttpUser):
    wait_time = between(0, 1)

    @task(3)
    def predict(self):
        self.client.post(
            "/api/predict",
            data=make_payload(),
            headers=HEADERS,
            name="/api/predict",
        )

    @task(1)
    def annotate(self):
        self.client.post(
            "/api/annotate",
            data=make_payload(),
            headers=HEADERS,
            name="/api/annotate",
        )
