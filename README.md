# Chat Task Application

A multi-service application built with Rails API and Go service for handling chat applications, chats, and messages. The architecture is designed to handle high-traffic scenarios by offloading chat and message creation to a high-performance Go service that uses Redis for fast operations and Sidekiq for asynchronous database writes.

## Architecture

- **Rails API**: Main REST API for applications, chats, and messages
- **Go Service**: High-performance service for creating chats and messages
- **Nginx**: Reverse proxy routing requests
- **MySQL**: Primary database
- **Redis**: Caching, job queue (Sidekiq), and counter storage
- **Elasticsearch**: Search functionality for messages
- **Sidekiq**: Background job processing for database writes

## High-Performance Design

### Go Service + Sidekiq Architecture

The application uses a two-tier approach for handling chat and message creation:

1. **Go Service (Fast Path)**: 
   - Handles POST requests for creating chats and messages
   - Uses Redis for ultra-fast operations (incrementing counters, validating tokens)
   - Immediately returns a response with the created chat/message number
   - Enqueues a Sidekiq job for asynchronous database persistence

2. **Sidekiq Workers (Background Processing)**:
   - `ChatsCreatorJob`: Persists chat records to MySQL database
   - `MessageCreatorJob`: Persists message records to MySQL database
   - Processes jobs asynchronously, avoiding database connection overhead during request handling

**Benefits:**
- **Low Latency**: Requests return immediately without waiting for database writes
- **High Throughput**: Redis operations are extremely fast, allowing thousands of requests per second
- **Scalability**: Database writes are batched through Sidekiq, reducing connection pool pressure
- **Reliability**: Sidekiq retries failed jobs, ensuring eventual consistency

### Request Flow

```
Client Request → Nginx → Go Service
                            ├─ Validate token (Redis)
                            ├─ Generate number (Redis INCR)
                            ├─ Update counters (Redis)
                            ├─ Enqueue Sidekiq job (Redis)
                            └─ Return response immediately
                                
Background: Sidekiq Worker
                            ├─ Process job from queue
                            ├─ Create record in MySQL
                            └─ Update search index (Elasticsearch)
```

## Prerequisites

- Docker and Docker Compose
- Git

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd luciq_chat_task
   ```

2. **Create environment file**
   ```bash
   cp .env.example .env
   ```
   
   The `.env.example` file contains all required environment variables with safe default values. You can modify the `.env` file if needed, but the defaults should work for development.

3. **Start the services**
   ```bash
   docker-compose up --build
   ```

   This will:
   - Build the Rails API and Go service containers
   - Start MySQL, Redis, and Elasticsearch
   - Start Nginx as the reverse proxy
   - Initialize the database and run migrations
4. **Access the application**
   - API: http://localhost

## API Endpoints

### Pagination

All index endpoints support pagination using query parameters:
- `page`: Page number (default: `1`)
- `per_page`: Items per page (default: `10`, max: `100`)

Example: `GET /api/v1/applications?page=2&per_page=20`

### Applications

#### List Applications
- **Endpoint**: `GET /api/v1/applications`
- **Query Parameters**:
  - `page` (optional): Page number (default: `1`)
  - `per_page` (optional): Items per page (default: `10`, max: `100`)
- **Response** (200 OK):
  ```json
  {
    "applications": [
      {
        "name": "My App",
        "token": "abc123def456ghi789jkl012mno345pqr678stu",
        "chats_count": 5,
        "created_at": "2025-11-11T00:00:00.000Z",
        "updated_at": "2025-11-11T00:00:00.000Z"
      }
    ],
    "meta": {
      "current_page": 1,
      "per_page": 10,
      "next_page": 2,
      "previous_page": null
    }
  }
  ```

#### Create Application
- **Endpoint**: `POST /api/v1/applications`
- **Request Body**:
  ```json
  {
    "application": {
      "name": "My Application"
    }
  }
  ```
- **Response** (201 Created):
  ```json
  {
    "name": "My Application",
    "token": "abc123def456ghi789jkl012mno345pqr678stu",
    "chats_count": 0,
    "created_at": "2025-11-11T00:00:00.000Z",
    "updated_at": "2025-11-11T00:00:00.000Z"
  }
  ```
- **Error Response** (422 Unprocessable Entity):
  ```json
  {
    "errors": {
      "name": ["can't be blank"]
    }
  }
  ```

#### Get Application
- **Endpoint**: `GET /api/v1/applications/:token`
- **Response** (200 OK):
  ```json
  {
    "name": "My Application",
    "token": "abc123def456ghi789jkl012mno345pqr678stu",
    "chats_count": 5,
    "created_at": "2025-11-11T00:00:00.000Z",
    "updated_at": "2025-11-11T00:00:00.000Z"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find an Application with token abc123..."
  }
  ```

#### Update Application
- **Endpoint**: `PUT /api/v1/applications/:token`
- **Request Body**:
  ```json
  {
    "application": {
      "name": "Updated Name"
    }
  }
  ```
- **Response** (200 OK):
  ```json
  {
    "name": "Updated Name",
    "token": "abc123def456ghi789jkl012mno345pqr678stu",
    "chats_count": 5,
    "created_at": "2025-11-11T00:00:00.000Z",
    "updated_at": "2025-11-11T01:00:00.000Z"
  }
  ```
- **Error Response** (422 Unprocessable Entity):
  ```json
  {
    "errors": {
      "name": ["can't be blank"]
    }
  }
  ```

#### Delete Application
- **Endpoint**: `DELETE /api/v1/applications/:token`
- **Response** (200 OK):
  ```json
  {
    "message": "Deleted successfully"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find a Application with token abc123..."
  }
  ```

### Chats

#### Create Chat (Handled by Go Service)
- **Endpoint**: `POST /api/v1/applications/:token/chats`
- **Description**: Creates a new chat for the application. This request is routed to the Go service for high-performance handling.
- **How it works**:
  1. Go service validates the application token in Redis
  2. Generates a unique chat number using Redis INCR
  3. Increments the application's chat count in Redis
  4. Initializes chat message counter in Redis
  5. Enqueues a `ChatsCreatorJob` to Sidekiq for database persistence
  6. Returns response immediately with the chat number and application token
- **Request**: No body required
- **Response** (201 Created):
  ```json
  {
    "chat": {
      "number": 1,
      "application_token": "abc123def456ghi789jkl012mno345pqr678stu",
      "timestamp": "2025-11-11T00:00:00.000000Z"
    }
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Application with token abc123... not found"
  }
  ```
- **Note**: The chat record is created in the database asynchronously by Sidekiq. The response is returned immediately without waiting for the database write.

#### List Chats
- **Endpoint**: `GET /api/v1/applications/:token/chats`
- **Query Parameters**:
  - `page` (optional): Page number (default: `1`)
  - `per_page` (optional): Items per page (default: `10`, max: `100`)
- **Response** (200 OK):
  ```json
  {
    "chats": [
      {
        "number": 1,
        "messages_count": 10,
        "created_at": "2025-11-11T00:00:00.000Z",
        "updated_at": "2025-11-11T00:00:00.000Z"
      },
      {
        "number": 2,
        "messages_count": 5,
        "created_at": "2025-11-11T01:00:00.000Z",
        "updated_at": "2025-11-11T01:00:00.000Z"
      }
    ],
    "meta": {
      "current_page": 1,
      "per_page": 10,
      "next_page": null,
      "previous_page": null
    }
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find an Application with token abc123..."
  }
  ```

#### Get Chat
- **Endpoint**: `GET /api/v1/applications/:token/chats/:number`
- **Response** (200 OK):
  ```json
  {
    "number": 1,
    "messages_count": 10,
    "created_at": "2025-11-11T00:00:00.000Z",
    "updated_at": "2025-11-11T00:00:00.000Z"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find a Chat with number 1"
  }
  ```

#### Delete Chat
- **Endpoint**: `DELETE /api/v1/applications/:token/chats/:number`
- **Response** (200 OK):
  ```json
  {
    "message": "Deleted successfully"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find a Chat with number 1"
  }
  ```

### Messages

#### Create Message (Handled by Go Service)
- **Endpoint**: `POST /api/v1/applications/:token/chats/:chat_number/messages`
- **Description**: Creates a new message in a chat. This request is routed to the Go service for high-performance handling.
- **How it works**:
  1. Go service validates the application token in Redis
  2. Validates that the chat exists (checks Redis cache)
  3. Generates a unique message number using Redis INCR
  4. Increments the chat's message count in Redis
  5. Enqueues a `MessageCreatorJob` to Sidekiq for database persistence
  6. Returns response immediately with the message number, body, chat number, and application token
- **Request Body**:
  ```json
  {
    "message": {
      "body": "Hello, this is a test message"
    }
  }
  ```
- **Response** (201 Created):
  ```json
  {
    "message": {
      "number": 1,
      "body": "Hello, this is a test message",
      "chat_number": 1,
      "application_token": "abc123def456ghi789jkl012mno345pqr678stu",
      "timestamp": "2025-11-11T00:00:00.000000Z"
    }
  }
  ```
- **Error Response** (400 Bad Request):
  ```json
  {
    "error": "Invalid request body: body is required"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Chat 1 not found for application abc123..."
  }
  ```
- **Note**: The message record is created in the database asynchronously by Sidekiq. The response is returned immediately without waiting for the database write.

#### List Messages
- **Endpoint**: `GET /api/v1/applications/:token/chats/:chat_number/messages`
- **Query Parameters**:
  - `page` (optional): Page number (default: `1`)
  - `per_page` (optional): Items per page (default: `10`, max: `100`)
- **Response** (200 OK):
  ```json
  {
    "messages": [
      {
        "number": 1,
        "body": "Hello, this is a test message",
        "created_at": "2025-11-11T00:00:00.000Z",
        "updated_at": "2025-11-11T00:00:00.000Z"
      },
      {
        "number": 2,
        "body": "Another message",
        "created_at": "2025-11-11T00:01:00.000Z",
        "updated_at": "2025-11-11T00:01:00.000Z"
      }
    ],
    "meta": {
      "current_page": 1,
      "per_page": 10,
      "next_page": null,
      "previous_page": null
    }
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find an Application with token abc123..."
  }
  ```
  or
  ```json
  {
    "error": "Can't find a Chat with number 1"
  }
  ```

#### Get Message
- **Endpoint**: `GET /api/v1/applications/:token/chats/:chat_number/messages/:message_number`
- **Response** (200 OK):
  ```json
  {
    "number": 1,
    "body": "Hello, this is a test message",
    "created_at": "2025-11-11T00:00:00.000Z",
    "updated_at": "2025-11-11T00:00:00.000Z"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find a Message with number 1"
  }
  ```

#### Update Message
- **Endpoint**: `PUT /api/v1/applications/:token/chats/:chat_number/messages/:message_number`
- **Request Body**:
  ```json
  {
    "message": {
      "body": "Updated message body"
    }
  }
  ```
- **Response** (200 OK):
  ```json
  {
    "number": 1,
    "body": "Updated message body",
    "created_at": "2025-11-11T00:00:00.000Z",
    "updated_at": "2025-11-11T01:00:00.000Z"
  }
  ```
- **Error Response** (422 Unprocessable Entity):
  ```json
  {
    "errors": {
      "body": ["can't be blank"]
    }
  }
  ```

#### Delete Message
- **Endpoint**: `DELETE /api/v1/applications/:token/chats/:chat_number/messages/:message_number`
- **Response** (200 OK):
  ```json
  {
    "message": "Deleted successfully"
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find a Message with number 1"
  }
  ```

#### Search Messages
- **Endpoint**: `GET /api/v1/applications/:token/chats/:chat_number/messages/search`
- **Description**: Search messages in a chat using Elasticsearch full-text search
- **Query Parameters**:
  - `query` (required): Search query string
  - `page` (optional): Page number (default: `1`)
  - `per_page` (optional): Items per page (default: `10`, max: `100`)
- **Example**: `GET /api/v1/applications/abc123.../chats/1/messages/search?query=hello&page=1&per_page=20`
- **Response** (200 OK):
  ```json
  {
    "messages": [
      {
        "number": 1,
        "body": "Hello, this is a test message",
        "created_at": "2025-11-11T00:00:00.000Z",
        "updated_at": "2025-11-11T00:00:00.000Z"
      }
    ],
    "meta": {
      "current_page": 1,
      "per_page": 10,
      "next_page": null,
      "previous_page": null
    }
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Can't find a Application with token abc123..."
  }
  ```
  or
  ```json
  {
    "error": "Can't find a Chat with number 1"
  }
  ```

## Postman Collection

A complete Postman collection is available for testing all API endpoints:

1. **Import the Collection**:
   - Open Postman
   - Click "Import" button
   - Select `Chat_Task_API.postman_collection.json`
   - The collection will be imported with all endpoints organized by folder

2. **Import the Environment** (Optional but recommended):
   - Click "Import" button
   - Select `Chat_Task_API.postman_environment.json`
   - Select the "Chat Task API - Local" environment from the environment dropdown
   - Update `base_url` if your API is running on a different host/port

3. **Using the Collection**:
   - Set the `base_url` variable (default: `http://localhost`)
   - Create an application using "Create Application" endpoint
   - Copy the `token` from the response and set it as `application_token` variable
   - Use the collection variables (`{{application_token}}`, `{{chat_number}}`, `{{message_number}}`) in requests
   - All endpoints are pre-configured with example request bodies and query parameters

### Collection Structure

- **Applications**: List, Create, Get, Update, Delete
- **Chats**: Create, List, Get, Delete
- **Messages**: Create, List, Get, Update, Delete, Search

All endpoints include:
- Proper HTTP methods
- Request headers (Content-Type: application/json)
- Example request bodies (where applicable)
- Query parameters for pagination
- Variable placeholders for easy testing

## Development

### Running Tests

The project uses RSpec for testing. To run the test suite:

```bash
# Run all tests
docker-compose exec rails-api bundle exec rspec

# Run specific test file
docker-compose exec rails-api bundle exec rspec spec/models/application_spec.rb

# Run tests with coverage
docker-compose exec rails-api bundle exec rspec --format documentation
```

## Project Structure

```
.
├── docker-compose.yaml                    # Docker Compose configuration
├── .env.example                          # Environment variables template
├── Chat_Task_API.postman_collection.json # Postman collection for API testing
├── Chat_Task_API.postman_environment.json # Postman environment variables
├── nginx/                                # Nginx configuration
│   └── nginx.conf
├── rails_api/                            # Rails API application
│   ├── app/
│   │   ├── controllers/                  # API controllers
│   │   ├── models/                       # ActiveRecord models
│   │   ├── jobs/                         # Sidekiq jobs
│   │   └── serializers/                  # JSON serializers
│   ├── config/
│   ├── db/                               # Database migrations
│   ├── spec/                             # RSpec test files
│   └── Dockerfile
└── go_service/                           # Go service
    ├── main.go
    └── Dockerfile
```

## Notes

- The `.env` file is git-ignored for security. Always use `.env.example` as a template.
- The Go service handles POST requests for creating chats and messages for better performance.
- All other requests are handled by the Rails API.
- Sidekiq processes background jobs for persisting chats and messages to the database.
- Chat and message numbers are generated using Redis INCR for uniqueness and performance.
- Application tokens are cached in Redis for fast validation.
- Message search is powered by Elasticsearch for full-text search capabilities.
- All index endpoints support pagination with `page` and `per_page` query parameters.
- Default pagination: 10 items per page, maximum 100 items per page.

## Performance Considerations

- **Redis Counters**: Chat and message counts are stored in Redis for fast reads and writes
- **Async Database Writes**: Database persistence happens asynchronously via Sidekiq
- **Connection Pooling**: Rails API uses connection pooling to manage database connections efficiently
- **Caching**: Application tokens are cached in Redis to avoid database lookups
- **Search Indexing**: Messages are indexed in Elasticsearch for fast search queries
- **Pagination**: All list endpoints are paginated to handle large datasets efficiently
