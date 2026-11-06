from fastapi import FastAPI, HTTPException, status
from psycopg.errors import OperationalError, UniqueViolation
from exceptions import BookNotFoundError

import db
from schemas import Book, BookCreate

app = FastAPI(title="Book API")


@app.get("/status", status_code=200)
def health():
    try:
        db.check_connection()
    except OperationalError:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database is unavailable"
        )

    return {"status": "ok"}


@app.get("/books", response_model=list[Book], status_code=200)
def list_books():
    return db.list_books()


@app.get("/books/{book_id}", response_model=Book, status_code=200)
def get_book(book_id: int):
    try:
        book = db.get_book(book_id)
    except BookNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Book not found")

    return book


@app.post("/books", response_model=Book, status_code=201)
def create_book(book: BookCreate):
    try:
        return db.create_book(book)
    except UniqueViolation:
        raise HTTPException(
            status.HTTP_409_CONFLICT, detail="A book with this ISBN already exists"
        )


@app.delete("/books/{book_id}", status_code=204)
def delete_book(book_id: int):
    try:
        db.delete_book(book_id)
    except BookNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Book not found")


@app.get("/books/isbn/{isbn13}", response_model=Book, status_code=200)
def get_book_by_isbn(isbn13: str):
    try:
        book = db.get_book_by_isbn(isbn13)
    except BookNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Book not found")

    return book
