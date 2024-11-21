# Chat System

## Architecture

### Design
![alt design](/assets/arch.png)

### Components

- **NGINX Reverse Proxy:** NGINX is used as a reverse proxy to route client requests to two different backend services (Go Web Service, Rails Web Service) based on defined paths, enabling centralized request handling

- **Rails Web Service:** Rails web service serves as the primary application, handling overall application management, message, and chat operations, except for the creation of messages and chats, which are delegated to Go Web Server.

- **Go Web Service:** Go web service handles the creation of chats and messages by pushing these tasks as jobs to the Redis queue for asynchronous processing.

- **Redis:** Redis is used as a Redis Queue for managing chat and message creation jobs. Additionally, it stores chat_count for each application and message_count for each chat to track their respective metrics efficiently.

- **Elasticsearch** Elasticsearch is integrated with the Rails service to enable efficient and scalable searching within message content.

- **Sidekiq Worker** Sidekiq workers pull jobs from the Redis queue to handle updates to applications, chats, and messages, ensuring the changes are reliably persisted in the MySQL database.

- **Go Worker** Go worker is responsible for processing chat and message creation jobs from the Redis queue and persisting the data in the MySQL database.

- **MySQL** MySQL is used as the primary database to store all persistent data, including applications, chats, messages.

## Database

### Schema
![alt schema](/assets/schema.png)

### Indexes
- **idx_application_token ON applications (token):** Speeds up queries filtering by token, which is often used for lookups.
- **idx_chat_application_id_chat_number ON chats (application_id, chat_number):** Enhances performance for queries filtering by application_id or by both application_id and chat_number together
- **idx_chat_number ON chats (chat_number):** Optimizes queries filtering directly by chat_number
- **idx_message_number ON messages (message_number):**  Improves performance for queries filtering by message_number
- **idx_message_chat_id_message_number ON messages (chat_id, message_number):** Speeds up queries filtering by chat_id and message_number, or just chat_id

## Concurrency 

### Handling Race conditions
- Use `SetNX` to ensure only one process can increment the chat counter at a time, preventing overlapping increments and guarantees consistent data updates for the chat counter.

![alt concurrent](/assets/concurrency.png)

- This approach used to ensure that `chat_number` and `message_number` are corretly updates and `applications(chat_counts)` and `chats(message_counts)` updated quickly.


### Further enhancement

#### 1. Presisting data failure
- **issue:** If presisting chat in MySQL failed for any reason, we have to roll back `chat_counter` in redis to ensure the counts is correct.
- **solution:** Before incrementing the chat counter in Redis, fetch and store the current `chat_counter` value and revert to the previous state in case of failure.


#### 2. Adding job to increament `chat_counts`, `message_counts`

- **Issue** Adding job to increament `applications(chat_counts)` and `chats(message_counts)` for each chat/message creation will make a huge load on database as it's double the number of queries on database, need workers to pull these jobs and update theses records.

- **Solution(1)** periodically synchronize with the database with counts stored in redis ~10min.

- **Solution(2)** Update only for certain thresholds ~100 messages.

- **Solution(3)** Combine last two approaches, update after ~100 message and after 10 min from last update.

## Documentation

**Swagger documentation**
```
http://localhost:8000/api-docs/
```

## How to run ?

```bash
$ git pull https://github.com/hossamasaad/chat-system/
$ docker compose up
```