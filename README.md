# CloudEco — Wildfire & Smoke Detection API

## Project Structure

```
cloudeco/
├── app/
│   └── main.py              # FastAPI application
├── model/
│   └── wildfire.pt          # YOLO model weights
├── k8s/
│   ├── deployment.yaml      # Kubernetes Deployment
│   └── service.yaml         # Kubernetes Service (NodePort)
├── terraform/
│   └── main.tf              # GCP VM provisioning
├── ansible/
│   └── k8s_setup.yaml       # Kubernetes cluster setup
├── locust/
│   └── locustfile.py        # Load test script
├── Dockerfile
├── requirements.txt
├── run_experiments.sh
└── README.md
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/predict` | Returns JSON with bounding boxes and class labels |
| POST | `/api/annotate` | Returns base64 annotated image |
| GET | `/health` | Health check |

### Request Payload
```json
{
  "uuid": "e4b2c1d0-8d2e-11eb-8dcd-0242ac130003",
  "image": "<base64-encoded-image>"
}
```

### Sample Response (/api/predict)
```json
{
  "uuid": "e4b2c1d0-8d2e-11eb-8dcd-0242ac130003",
  "count": 2,
  "detections": ["fire", "smoke"],
  "boxes": [
    {"x": 264.42, "y": 16.61, "width": 652.17, "height": 344.2, "probability": 0.79}
  ],
  "speed_preprocess_ms": 2.99,
  "speed_inference_ms": 626.08,
  "speed_postprocess_ms": 1.08
}
```

---

## How to Run

### 1. Prerequisites
- Docker, kubectl, terraform, ansible, locust installed
- GCP account with billing enabled

### 2. Provision Infrastructure (Terraform)
```bash
cd terraform/
terraform init
terraform apply
```

### 3. Set Up Kubernetes Cluster (Ansible)
```bash
cd ansible/
ansible-playbook -i inventory.ini k8s_setup.yaml
```

### 4. Build & Push Docker Image
```bash
docker buildx build --platform linux/amd64 -t mukdagar/cloudeco:latest --push .
```

### 5. Deploy to Kubernetes
```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -w
```

### 6. Test the API
```bash
IMAGE_B64=$(base64 -i test_image.jpg | tr -d '\n')
curl -X POST http://35.223.85.181:31486/api/predict \
  -H "Content-Type: application/json" \
  -d "{\"uuid\": \"test-001\", \"image\": \"$IMAGE_B64\"}"
```

### 7. Run Load Tests
```bash
cd locust/
locust -f locustfile.py --host http://35.223.85.181:31486
# Open http://localhost:8089
```

### 8. Scale Pods for Benchmarking
```bash
kubectl scale deployment cloudeco-deployment --replicas=2
kubectl scale deployment cloudeco-deployment --replicas=4
kubectl scale deployment cloudeco-deployment --replicas=8
```

---

## Architecture

- **FastAPI** handles async HTTP requests
- **YOLO inference** runs in a ThreadPoolExecutor to avoid blocking the event loop
- **Docker** image uses CPU-only PyTorch (~2GB saved vs GPU build)
- **Kubernetes** NodePort service exposes the app on port 31486
- **GCP VMs** — 3 x n2-standard-4 (4 vCPU, 16GB RAM each)
- **Pod limits** — 1.0 vCPU, 1Gi memory per pod
