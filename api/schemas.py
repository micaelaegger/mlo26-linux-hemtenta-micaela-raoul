from pydantic import BaseModel, Field


class BookCreate(BaseModel):
    title: str = Field(min_length=1)
    authors: list[str] = Field(min_length=1)
    isbn13: str = Field(pattern=r"^\d{13}$")
    year_published: int = Field(ge=0, le=9999)
    publisher: str | None = None


class Book(BookCreate):
    id: int
