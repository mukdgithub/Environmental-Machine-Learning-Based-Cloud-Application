import asyncio
import base64
import cv2
import numpy as np
from concurrent.futures import ThreadPoolExecutor
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from ultralytics import YOLO

app = FastAPI(title="CloudEco - Wildfire & Smoke Detection API")

executor = ThreadPoolExecutor(max_workers=4)
model = None


@app.on_event("startup")
async def load_model():
    global model
    model = YOLO("/app/model/wildfire.pt")
    dummy = np.zeros((640, 640, 3), dtype=np.uint8)
    model(dummy, verbose=False)
    print("Model loaded and warmed up.")


class PredictRequest(BaseModel):
    uuid: str
    image: str


def decode_image(b64_string: str) -> np.ndarray:
    img_bytes = base64.b64decode(b64_string)
    np_arr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image.")
    return img


def run_predict(b64_string: str) -> dict:
    img = decode_image(b64_string)
    results = model(img, verbose=False)
    result = results[0]
    speed = result.speed

    detections = []
    boxes_payload = []

    if result.boxes is not None and len(result.boxes) > 0:
        for box in result.boxes:
            cls_id = int(box.cls[0])
            label = model.names[cls_id]
            conf = float(box.conf[0])
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            detections.append(label)
            boxes_payload.append({
                "x": round(x1, 2),
                "y": round(y1, 2),
                "width": round(x2 - x1, 2),
                "height": round(y2 - y1, 2),
                "probability": round(conf, 4),
            })

    return {
        "detections": detections,
        "boxes": boxes_payload,
        "speed": speed,
    }


def run_annotate(b64_string: str) -> str:
    img = decode_image(b64_string)
    results = model(img, verbose=False)
    result = results[0]
    annotated = result.plot()
    _, buffer = cv2.imencode(".jpg", annotated)
    return base64.b64encode(buffer).decode("utf-8")


@app.post("/api/predict")
async def predict(request: PredictRequest):
    try:
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(executor, run_predict, request.image)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return {
        "uuid": request.uuid,
        "count": len(result["detections"]),
        "detections": result["detections"],
        "boxes": result["boxes"],
        "speed_preprocess_ms": result["speed"].get("preprocess", 0),
        "speed_inference_ms": result["speed"].get("inference", 0),
        "speed_postprocess_ms": result["speed"].get("postprocess", 0),
    }


@app.post("/api/annotate")
async def annotate(request: PredictRequest):
    try:
        loop = asyncio.get_event_loop()
        annotated_b64 = await loop.run_in_executor(executor, run_annotate, request.image)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return {
        "uuid": request.uuid,
        "annotated_image": annotated_b64,
    }


@app.get("/health")
async def health():
    return {"status": "ok"}
