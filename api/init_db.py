import os

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()


def get_connection():
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        row_factory=dict_row,
    )


def create_books_table():
    with get_connection() as con:
        con.execute(
            """
            CREATE TABLE IF NOT EXISTS books (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                authors TEXT[] NOT NULL,
                isbn13 TEXT NOT NULL UNIQUE,
                year_published INTEGER NOT NULL,
                publisher TEXT
            )
            """
        )


def seed_books():
    books = [
        ("Dune", ["Frank Herbert"], "9780441013593", 1965, "Ace"),
        ("1984", ["George Orwell"], "9780451524935", 1949, "Signet Classics"),
        (
            "The Hobbit",
            ["J.R.R. Tolkien"],
            "9780547928227",
            1937,
            "Houghton Mifflin Harcourt",
        ),
        (
            "To Kill a Mockingbird",
            ["Harper Lee"],
            "9780061120084",
            1960,
            "Harper Perennial",
        ),
        (
            "Good Omens",
            ["Terry Pratchett", "Neil Gaiman"],
            "9780060853983",
            1990,
            "William Morrow",
        ),
    ]

    with get_connection() as con:
        with con.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO books (title, authors, isbn13, year_published, publisher)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (isbn13) DO NOTHING
                """,
                books,
            )


# Run once on the server with: python init_db.py
if __name__ == "__main__":
    create_books_table()
    print("Table 'books' is ready.")
    seed_books()
    print("Sample books added.")
