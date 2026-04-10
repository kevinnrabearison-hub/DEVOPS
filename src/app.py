from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from src.utils import format_item, get_version

app = FastAPI(
    title="Mon API DevSecOps",
    description="API FastAPI déployée via pipeline CI/CD sécurisé",
    version="1.0.0"
)


class Item(BaseModel):
    name: str
    description: str = ""
    price: float


@app.get("/")
def root():
    return {"message": "Bienvenue sur l'API", "version": get_version()}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/items/{item_id}")
def get_item(item_id: int):
    if item_id <= 0:
        raise HTTPException(status_code=400, detail="ID invalide")
    return {"item_id": item_id, "name": format_item(f"item-{item_id}")}


@app.post("/items")
def create_item(item: Item):
    if item.price < 0:
        raise HTTPException(status_code=400, detail="Prix invalide")
    return {"message": "Item créé", "item": item}
