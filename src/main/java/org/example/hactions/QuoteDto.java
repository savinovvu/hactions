package org.example.hactions;

public class QuoteDto {
    private String id;
    private String text;
    private String author;

    // Конструкторы
    public QuoteDto() {}

    public QuoteDto(String id, String text, String author) {
        this.id = id;
        this.text = text;
        this.author = author;
    }

    // Геттеры и сеттеры
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }

    @Override
    public String toString() {
        return "QuoteDto{" +
                "id=" + id +
                ", text='" + text + '\'' +
                ", author='" + author + '\'' +
                '}';
    }
}