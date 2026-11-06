from init_db import get_connection
from exceptions import BookNotFoundError


# Raises an error if the database cannot be reached.
def check_connection():
    with get_connection() as con:
        con.execute("SELECT 1")


def list_books():
    with get_connection() as con:
        return con.execute("SELECT * FROM books ORDER BY id").fetchall()


# Returns the book. Raises BookNotFoundError if it does not exist.
def get_book(book_id):
    with get_connection() as con:
        book = con.execute("SELECT * FROM books WHERE id = %s", (book_id,)).fetchone()
    if book is None:
        raise BookNotFoundError()
    return book


# Returns the book. Raises BookNotFoundError if it does not exist.
def get_book_by_isbn(isbn13):
    with get_connection() as con:
        book = con.execute(
            "SELECT * FROM books WHERE isbn13 = %s", (isbn13,)
        ).fetchone()
    if book is None:
        raise BookNotFoundError()
    return book


# Returns the new book including its id.
# Raises psycopg.errors.UniqueViolation if the ISBN already exists.
def create_book(book):
    # The %s placeholders let psycopg send the values separately from the SQL,
    # which protects against SQL injection. Never build SQL with f-strings.
    with get_connection() as con:
        return con.execute(
            """
            INSERT INTO books (title, authors, isbn13, year_published, publisher)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING *
            """,
            (
                book.title,
                book.authors,
                book.isbn13,
                book.year_published,
                book.publisher,
            ),
        ).fetchone()


# Raises BookNotFoundError if the book does not exist.
def delete_book(book_id):
    with get_connection() as con:
        deleted = con.execute(
            "DELETE FROM books WHERE id = %s RETURNING id", (book_id,)
        ).fetchone()
    if deleted is None:
        raise BookNotFoundError()
