
import requests
import json
from datetime import datetime

url = "https://pulse-track-backend-1-bgfi.onrender.com/api/bpm/add"
payload = {
    "userId": "69fb1ff9d7b4fe27f29d1706",
    "bpm": 77,
    "status": "Healthy [V:99,118,78]",
    "timestamp": datetime.utcnow().isoformat() + "Z"
}
headers = {
    "Content-Type": "application/json"
}

print(f"Testing POST to {url}...")
response = requests.post(url, data=json.dumps(payload), headers=headers)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
