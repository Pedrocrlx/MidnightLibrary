# Midnight Library

A comprehensive web-based application for managing library operations, including book inventory, user management, and borrowing processes. This project focuses on robust database design and efficient data handling.

## Project Overview

This Library Management System is built with Django and PostgreSQL, designed to streamline the operations of a modern library. It provides distinct interfaces for administrators (librarians) and standard users, ensuring secure and efficient access to library resources.

## Database Design

The core of this project is its relational database schema, designed to ensure data integrity and efficient querying.

### ER Diagram Description

The database consists of the following key entities and relationships:

*   **Users**: Stores user information including authentication credentials and roles (admin/user).
*   **Books**: Manages the inventory of books, including details like title, author, quantity, and thumbnail.
*   **Categories**: Defines the various genres or categories of books.
*   **BooksBorrowed**: A junction table recording borrowing transactions. It links `Users` and `Books`, tracking who borrowed what, when, and the due date.
*   **CategoriesPerBook**: A junction table implementing a Many-to-Many relationship between `Books` and `Categories`, allowing a book to belong to multiple categories.

### Schema Details  

#### 1. Users Table
| Field | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | Primary Key | Unique identifier for the user |
| `name` | Varchar(100) | Not Null | Full name of the user |
| `email` | EmailField | Unique, Not Null | User's email address (used for login) |
| `password` | Varchar(100) | Not Null | Hashed password |
| `role` | Varchar(10) | Default='user' | Role of the user ('admin' or 'user') |

#### 2. Books Table
| Field | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | Primary Key | Unique identifier for the book |
| `book_name` | Varchar(100) | Not Null | Title of the book |
| `author` | Varchar(100) | Not Null | Author of the book |
| `thumbnail` | URLField | Nullable | URL to the book cover image |
| `quantity` | Integer | Default=1 | Number of copies available |

#### 3. BooksBorrowed Table
| Field | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | Primary Key | Unique identifier for the transaction |
| `user_id` | ForeignKey | References Users(id) | The user who borrowed the book |
| `book_id` | ForeignKey | References Books(id) | The book being borrowed |
| `borrowed_date` | Date | Auto Now Add | Date when the book was borrowed |
| `due_date` | DateTime | Default (+60 days) | Date when the book is due |

#### 4. Categories Table
| Field | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | Primary Key | Unique identifier for the category |
| `category_name` | Varchar(100) | Not Null | Name of the category (e.g., Fiction, Science) |

#### 5. CategoriesPerBook Table
| Field | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | Primary Key | Unique identifier |
| `book_id` | ForeignKey | References Books(id) | The book |
| `category_id` | ForeignKey | References Categories(id) | The category |

## Features

### User Features
*   **Browse & Search**: View all available books and search by title or author.
*   **Authentication**: Secure registration and login system.
*   **Borrowing**: Borrow available books (limit: 3 books per user).
*   **Dashboard**: View borrowed books and return them.
*   **Validation**: Cannot borrow out-of-stock books or duplicate copies.

### Admin Features
*   **Dashboard**: Overview of total books, borrowed books, and inventory stats.
*   **Inventory Management**: Add, update, and delete books.
*   **Category Management**: Add new categories and assign them to books.
*   **User Oversight**: View borrowing status of all books.

## Technologies Used

*   **Backend**: Django 5.2 (Python 3.12)
*   **Database**: PostgreSQL 17
*   **Containerization**: Docker & Docker Compose
*   **Dependency Management**: Poetry
*   **Testing**: Pytest & Pytest-Django

## Setup & Installation

### Prerequisites
*   Docker & Docker Compose
*   Make (optional, for easy commands)

### Running the Project

1.  **Clone the repository**
    ```bash
    git clone <repository-url>
    cd library-management-system
    ```

2.  **Start the application**
    Use the `make` command to build and start the containers, run migrations, and load initial data.
    ```bash
    make run
    ```
    *   Access the app at: `http://localhost:8000`
    *   Access Adminer (DB GUI) at: `http://localhost:8080`

3.  **Stop the application**
    ```bash
    make down
    ```

4.  **Clean up (Remove volumes & containers)**
    ```bash
    make clean
    ```

## Testing

The project includes a comprehensive integration test suite using `pytest`.

To run the tests inside the Docker container:
```bash
make test
```

### Test Coverage
*   Public access & Search
*   Authentication flows (Login/Register/Logout)
*   Borrowing logic & limits
*   Admin CRUD operations
*   Permission & Security checks

## Production deployment (Ubuntu 22.04 + Cloudflare)

Production uses `compose.prod.yaml`: only Nginx publishes ports (`80` and
`443`); Django, PostgreSQL and their Docker network remain private. Nginx uses
a Cloudflare Origin Certificate and the host firewall accepts web traffic only
from Cloudflare's published IP ranges.

On the VPS, clone the repository and run:

```bash
chmod +x scripts/setup-production.sh
./scripts/setup-production.sh
```

The wizard configures `.env`, installs the Origin Certificate, sets UFW rules,
starts the stack, and runs Django's deployment checks. Keep the DNS record
proxied and Cloudflare SSL/TLS mode set to **Full (strict)**. Before enabling
UFW, verify the SSH port with `sudo sshd -T | grep '^port'`; Ubuntu's default is
port `22`.

Useful production commands:

```bash
docker compose -f compose.prod.yaml ps
docker compose -f compose.prod.yaml logs -f nginx app
docker compose -f compose.prod.yaml exec app poetry run python django-app/manage.py createsuperuser
docker compose -f compose.prod.yaml pull
docker compose -f compose.prod.yaml up -d --build
```
