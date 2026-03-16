"""
Lambda Web Adapter Sample – FastAPI application

DynamoDB table structure:
  PK: "ITEM#{item_id}"   (partition key)
  SK: "ITEM#{item_id}"   (sort key)
"""

import os
import uuid
from contextlib import asynccontextmanager
from typing import Optional

import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# DynamoDB client
# ---------------------------------------------------------------------------
TABLE_NAME = os.environ.get("TABLE_NAME", "lambda-web-adapter-sample-dev")
AWS_REGION = os.environ.get("AWS_REGION", "us-west-2")

dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
table = dynamodb.Table(TABLE_NAME)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class ItemCreate(BaseModel):
    name: str
    description: Optional[str] = None


class ItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


class Item(BaseModel):
    id: str
    name: str
    description: Optional[str] = None


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup: verify table connection
    try:
        table.load()
    except ClientError as e:
        print(f"[WARN] Could not connect to DynamoDB table '{TABLE_NAME}': {e}")
    yield


app = FastAPI(
    title="Lambda Web Adapter Sample",
    description="FastAPI + DynamoDB running on Lambda via Lambda Web Adapter",
    version="0.1.0",
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------
@app.get("/health")
async def health():
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Items CRUD
# ---------------------------------------------------------------------------
@app.post("/items", response_model=Item, status_code=201)
async def create_item(payload: ItemCreate):
    item_id = str(uuid.uuid4())
    item = {
        "PK": f"ITEM#{item_id}",
        "SK": f"ITEM#{item_id}",
        "id": item_id,
        "name": payload.name,
        "description": payload.description,
    }
    try:
        table.put_item(Item=item)
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))
    return Item(**item)


@app.get("/items/{item_id}", response_model=Item)
async def get_item(item_id: str):
    try:
        response = table.get_item(
            Key={"PK": f"ITEM#{item_id}", "SK": f"ITEM#{item_id}"}
        )
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))

    item = response.get("Item")
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return Item(**item)


@app.put("/items/{item_id}", response_model=Item)
async def update_item(item_id: str, payload: ItemUpdate):
    # build update expression dynamically
    update_parts = []
    expr_values = {}
    expr_names = {}

    if payload.name is not None:
        update_parts.append("#n = :name")
        expr_values[":name"] = payload.name
        expr_names["#n"] = "name"

    if payload.description is not None:
        update_parts.append("#d = :desc")
        expr_values[":desc"] = payload.description
        expr_names["#d"] = "description"

    if not update_parts:
        raise HTTPException(status_code=400, detail="No fields to update")

    try:
        response = table.update_item(
            Key={"PK": f"ITEM#{item_id}", "SK": f"ITEM#{item_id}"},
            UpdateExpression="SET " + ", ".join(update_parts),
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames=expr_names,
            ConditionExpression="attribute_exists(PK)",
            ReturnValues="ALL_NEW",
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise HTTPException(status_code=404, detail="Item not found")
        raise HTTPException(status_code=500, detail=str(e))

    return Item(**response["Attributes"])


@app.delete("/items/{item_id}", status_code=204)
async def delete_item(item_id: str):
    try:
        table.delete_item(
            Key={"PK": f"ITEM#{item_id}", "SK": f"ITEM#{item_id}"},
            ConditionExpression="attribute_exists(PK)",
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise HTTPException(status_code=404, detail="Item not found")
        raise HTTPException(status_code=500, detail=str(e))
