package main

import (
	"context"
	"database/sql"
	"fmt"
	env "github.com/caitlinelfring/go-env-default"
	"github.com/gin-gonic/gin"
	_ "github.com/go-sql-driver/mysql"
	"github.com/jrallison/go-workers"
	"github.com/redis/go-redis/v9"
	"log"
	"net/http"
	"strconv"
	"time"
)

var (
	PORT                        = "8080"
	CREATE_CHAT_QUEUE           = "create_chat"
	CREATE_MESSAGE_QUEUE        = "create_message"
	UPDATE_CHATS_COUNT_QUEUE    = "update_chat_counters"
	UPDATE_MESSAGE_COUNTS_QUEUE = "update_messages_counts"
	REDIS_HOST                  = env.GetDefault("REDIS_HOST", "localhost:6379")
	REDIS_DB                    = "0"
	REDIS_POOL                  = "10"
	MYSQL_HOST                  = env.GetDefault("MYSQL_HOST", "localhost")
	MYSQL_PORT                  = 3306
	MYSQL_DB                    = "chat-app"
	MYSQL_USERNAME              = "root"
	MYSQL_PASSWORD              = "123"
	LOCK_TTL                    = 5 * time.Second
	LOCK_VALUE_CHAT             = "chat_lock_key"
	LOCK_VALUE_MESSAGE          = "chat_lock_message"
)

func initializeSideKiqWorker() {
	workers.Configure(map[string]string{
		"server":   REDIS_HOST,
		"database": REDIS_DB,
		"pool":     REDIS_POOL,
		"process":  "1",
	})
}

func addJob(queue string, args ...interface{}) string {
	jobId, err := workers.Enqueue(queue, "Add", args)
	if err != nil {
		return ""
	}
	return jobId
}

func createChat(c *gin.Context) {
	token := c.Param("token")
	exists, applicationId := getApplicationIdIfExists(token)
	if !exists {
		c.IndentedJSON(http.StatusNotFound, map[string]interface{}{"error_message": "Application with token not found"})
		return
	}

	rdb := redis.NewClient(&redis.Options{Addr: REDIS_HOST})
	ctx := context.Background()
	key := fmt.Sprintf("%d:chat_counter", applicationId)
	lockKey := fmt.Sprintf("%s:lock", key)

	// Step 1: Acquire lock
	acquired, err := rdb.SetNX(ctx, lockKey, LOCK_VALUE_CHAT, LOCK_TTL).Result()
	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, map[string]interface{}{"error_message": err.Error()})
		return
	}

	if !acquired {
		c.IndentedJSON(http.StatusNotFound, map[string]interface{}{"error_message": "Couldn't acquire lock"})
		return
	}

	chatNumber, err := rdb.Incr(ctx, key).Result()
	if err != nil {
		c.IndentedJSON(http.StatusNotFound, map[string]interface{}{"error_message": "Error incrementing the chat counter"})
		// Ensure the lock is released in case of error
		rdb.Del(ctx, lockKey)
		return
	}

	// Step 3: Release lock
	rdb.Del(ctx, lockKey)

	jobId := addJob(CREATE_CHAT_QUEUE, applicationId, chatNumber)
	response := map[string]interface{}{
		"chat_number": chatNumber,
		"message":     "Chat creation request submitted",
		"jobId":       jobId,
	}
	c.IndentedJSON(http.StatusCreated, response)
}

func createMessage(c *gin.Context) {
	token := c.Param("token")
	chatNumber, _ := strconv.Atoi(c.Param("chatNumber"))
	exists, applicationId, chatId := getApplicationIdAndChatIdIfExists(token, chatNumber)
	if !exists {
		c.IndentedJSON(http.StatusNotFound, map[string]interface{}{"error_message": "Application or chat not found"})
		return
	}

	rdb := redis.NewClient(&redis.Options{Addr: REDIS_HOST})
	ctx := context.Background()
	key := fmt.Sprintf("%d:%d:message_counter", applicationId, chatId)
	lockKey := fmt.Sprintf("%s:lock", key)

	// Step 1: Acquire lock
	acquired, err := rdb.SetNX(ctx, lockKey, LOCK_VALUE_MESSAGE, LOCK_TTL).Result()
	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, map[string]interface{}{"error_message": err.Error()})
		return
	}

	if !acquired {
		c.IndentedJSON(http.StatusNotFound, map[string]interface{}{"error_message": "Couldn't acquire lock"})
		return
	}

	var data map[string]interface{}
	if err := c.BindJSON(&data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	messageNumber, err := rdb.Incr(ctx, key).Result()
	if err != nil {
		c.IndentedJSON(http.StatusNotFound, map[string]interface{}{"error_message": "Error incrementing the message counter"})
		// Ensure the lock is released in case of error
		rdb.Del(ctx, lockKey)
		return
	}
	// Step 3: Release lock
	rdb.Del(ctx, lockKey)

	messageContent := data["content"].(string)
	jobId := addJob(CREATE_MESSAGE_QUEUE, chatId, messageNumber, messageContent)
	response := map[string]interface{}{
		"message_number": messageNumber,
		"message":        "Message creation request submitted",
		"jobId":          jobId,
	}
	c.IndentedJSON(http.StatusCreated, response)
}

func createChatJob(message *workers.Msg) {
	args, err := message.Args().Array()
	if err != nil {
		fmt.Println("Failed to parse args. JID: " + message.Jid())
		return
	}
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DB)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error opening database:", err)
	}
	defer db.Close()

	applicationId := args[0]
	chatNumber := args[1]
	query := "INSERT INTO chats (application_id, chat_number, messages_count, created_at, updated_at) VALUES (?, ?, 0, NOW(), NOW())"
	_, err = db.Exec(query, applicationId, chatNumber)
	if err != nil {
		log.Fatal(err, "JID:"+message.Jid())
	}
	addJob(UPDATE_CHATS_COUNT_QUEUE, applicationId, chatNumber)
	fmt.Printf("Chat Created. JID: %s\n", message.Jid())
}

func createMessageJob(message *workers.Msg) {
	args, err := message.Args().Array()
	if err != nil {
		fmt.Println("Failed to parse args. JID: " + message.Jid())
		return
	}
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DB)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error opening database:", err)
	}
	defer db.Close()

	chatId := args[0]
	messageNumber := args[1]
	messageContent := args[2]

	query := "INSERT INTO messages (chat_id, message_number, message_content, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())"

	_, err = db.Exec(query, chatId, messageNumber, messageContent)
	if err != nil {
		log.Fatal(err, "JID:"+message.Jid())
	}
	addJob(UPDATE_MESSAGE_COUNTS_QUEUE, chatId, messageNumber)
	fmt.Printf("Message Created. JID: %s\n", message.Jid())
}

func updateChatsCountJob(message *workers.Msg) {
	args, err := message.Args().Array()
	if err != nil {
		fmt.Println("Failed to parse args. JID: " + message.Jid())
		return
	}
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DB)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error opening database:", err)
	}
	defer db.Close()

	applicationId := args[0]
	chatsCount := args[1]

	query := "UPDATE applications SET chats_count = ? WHERE id = ?"
	_, err = db.Exec(query, chatsCount, applicationId)
	if err != nil {
		log.Fatal(err, "JID:"+message.Jid())
		return
	}
	fmt.Printf("Chats count updated. JID: %s\n", message.Jid())
}

func updateMessagesCountJob(message *workers.Msg) {
	args, err := message.Args().Array()
	if err != nil {
		fmt.Println("Failed to parse args. JID: " + message.Jid())
		return
	}
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DB)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error opening database:", err)
	}
	defer db.Close()

	chatId := args[0]
	messagesCount := args[1]

	query := "UPDATE chats SET messages_count = ? WHERE id = ?"
	_, err = db.Exec(query, messagesCount, chatId)
	if err != nil {
		log.Fatal(err, "JID:"+message.Jid())
		return
	}
	fmt.Printf("Message counts updated. JID: %s\n", message.Jid())
}

func getApplicationIdIfExists(token string) (bool, int) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DB)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error opening database:", err)
		return false, -1
	}
	defer db.Close()

	query := "SELECT id FROM applications WHERE token=?"
	rows, err := db.Query(query, token)
	if err != nil {
		log.Fatal(err)
		return false, 0
	}
	var id int
	if rows.Next() {
		rows.Scan(&id)
		return true, id
	}
	return false, 0
}

func getApplicationIdAndChatIdIfExists(token string, chatNumber int) (bool, int, int) {
	exists, applicationId := getApplicationIdIfExists(token)
	if !exists {
		return false, 0, 0
	}
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DB)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error opening database:", err)
	}
	defer db.Close()

	query := "SELECT id FROM chats WHERE application_id=? AND chat_number=?"
	rows, err := db.Query(query, applicationId, chatNumber)
	if err != nil {
		log.Fatal(err)
		return false, 0, 0
	}
	var id int
	if rows.Next() {
		rows.Scan(&id)
		return true, applicationId, id
	}
	return false, applicationId, 0
}

func main() {
	initializeSideKiqWorker()
	workers.Process(CREATE_CHAT_QUEUE, createChatJob, 5)
	workers.Process(CREATE_MESSAGE_QUEUE, createMessageJob, 5)
	workers.Process(UPDATE_CHATS_COUNT_QUEUE, updateChatsCountJob, 5)
	workers.Process(UPDATE_MESSAGE_COUNTS_QUEUE, updateMessagesCountJob, 5)
	go workers.Run()

	router := gin.Default()
	router.POST("/applications/:token/chats", createChat)
	router.POST("/applications/:token/chats/:chatNumber/messages", createMessage)

	if err := router.Run(":" + PORT); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
