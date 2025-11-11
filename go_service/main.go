package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

const (
	defaultRedisAddr     = "redis:6379"
	defaultPort          = "8080"
	requestTimeout       = 10 * time.Second
	redisConnectTimeout  = 5 * time.Second
	jidByteLength        = 12
)

const (
	sidekiqJobClassChatsConsumer   = "ChatsCreatorJob"
	sidekiqJobClassMessageCreator   = "MessageCreatorJob"
	sidekiqQueueChatsCreation      = "chats_creation_queue"
	sidekiqQueueMessageCreation     = "messages_creation_queue"
)

var rdb *redis.Client

type Chat struct {
	Number           int64     `json:"number"`
	ApplicationToken string    `json:"application_token"`
	TimeStamp        time.Time `json:"timestamp"`
}

type ChatResponse struct {
	Chat Chat `json:"chat"`
}

type Message struct {
	Number           int64     `json:"number"`
	Body             string    `json:"body"`
	ChatNumber       int64     `json:"chat_number"`
	ApplicationToken string    `json:"application_token"`
	TimeStamp        time.Time `json:"timestamp"`
}

type MessageCreateRequest struct {
	Message struct {
		Body string `json:"body" binding:"required"`
	} `json:"message" binding:"required"`
}

type MessageResponse struct {
	Message Message `json:"message"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type SidekiqJob struct {
	Class      string        `json:"class"`
	Args       []interface{} `json:"args"`
	Retry      bool          `json:"retry"`
	Queue      string        `json:"queue"`
	Jid        string        `json:"jid"`
	CreatedAt  time.Time     `json:"created_at"`
	EnqueuedAt time.Time     `json:"enqueued_at"`
}

func init() {
	initializeRedis()
}

func initializeRedis() {
	redisAddr := defaultRedisAddr

	rdb = redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "",
		DB:       0,
	})

	ctx, cancel := context.WithTimeout(context.Background(), redisConnectTimeout)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}

	log.Println("Successfully connected to Redis")
}

func main() {
	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := setupRouter()

	port := os.Getenv("GO_SERVICE_PORT")
	if port == "" {
		port = defaultPort
	}

	log.Printf("Starting server on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func setupRouter() *gin.Engine {
	router := gin.Default()

	router.GET("/health", healthCheck)

	v1 := router.Group("/api/v1")
	{
		applications := v1.Group("/applications")
		{
			applications.POST("/:token/chats", createChat)
			applications.POST("/:token/chats/:chat_number/messages", createMessage)
		}
	}

	return router
}

func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func createChat(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), requestTimeout)
	defer cancel()

	appToken := c.Param("token")
	if appToken == "" {
		respondWithError(c, http.StatusBadRequest, "Application token is required")
		return
	}

	if err := validateApplicationToken(ctx, appToken); err != nil {
		handleValidationError(c, err, appToken)
		return
	}

	lastChatNumberKey := fmt.Sprintf("application:%s:last_chat_number", appToken)
	chatsCountKey := fmt.Sprintf("application:%s", appToken)

	chatNumber, err := rdb.Incr(ctx, lastChatNumberKey).Result()
	if err != nil {
		log.Printf("Redis error while incrementing last chat number: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	if _, err := rdb.Incr(ctx, chatsCountKey).Result(); err != nil {
		log.Printf("Redis error while incrementing chats count: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	chatMessagesCountKey := fmt.Sprintf("application:%s:chat:%d", appToken, chatNumber)
	if err := rdb.Set(ctx, chatMessagesCountKey, 0, 0).Err(); err != nil {
		log.Printf("Redis error while initializing chat messages count: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	chat := Chat{
		Number:           chatNumber,
		ApplicationToken: appToken,
		TimeStamp:        time.Now(),
	}

	if err := enqueueChatCreationJob(ctx, chat); err != nil {
		log.Printf("Error enqueueing chat creation job: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	c.JSON(http.StatusCreated, ChatResponse{Chat: chat})
}

func createMessage(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), requestTimeout)
	defer cancel()

	appToken := c.Param("token")
	if appToken == "" {
		respondWithError(c, http.StatusBadRequest, "Application token is required")
		return
	}

	chatNumberStr := c.Param("chat_number")
	if chatNumberStr == "" {
		respondWithError(c, http.StatusBadRequest, "Chat number is required")
		return
	}

	var chatNumber int64
	if _, err := fmt.Sscanf(chatNumberStr, "%d", &chatNumber); err != nil {
		respondWithError(c, http.StatusBadRequest, "Invalid chat number format")
		return
	}

	var req MessageCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, http.StatusBadRequest, "Invalid request body: body is required")
		return
	}

	if err := validateApplicationToken(ctx, appToken); err != nil {
		handleValidationError(c, err, appToken)
		return
	}

	chatMessagesCountKey := fmt.Sprintf("application:%s:chat:%d", appToken, chatNumber)
	exists, err := rdb.Exists(ctx, chatMessagesCountKey).Result()
	if err != nil {
		log.Printf("Redis error while validating chat: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}
	if exists == 0 {
		respondWithError(c, http.StatusNotFound, fmt.Sprintf("Chat %d not found for application %s", chatNumber, appToken))
		return
	}

	lastMessageNumberKey := fmt.Sprintf("application:%s:chat:%d:last_message_number", appToken, chatNumber)
	messageNumber, err := rdb.Incr(ctx, lastMessageNumberKey).Result()
	if err != nil {
		log.Printf("Redis error while incrementing last message number: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	if _, err := rdb.Incr(ctx, chatMessagesCountKey).Result(); err != nil {
		log.Printf("Redis error while incrementing chat messages count: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	message := Message{
		Number:           messageNumber,
		Body:             req.Message.Body,
		ChatNumber:       chatNumber,
		ApplicationToken: appToken,
		TimeStamp:        time.Now(),
	}

	if err := enqueueMessageCreationJob(ctx, message); err != nil {
		log.Printf("Error enqueueing message creation job: %v", err)
		respondWithError(c, http.StatusInternalServerError, "Internal server error")
		return
	}

	c.JSON(http.StatusCreated, MessageResponse{Message: message})
}

func validateApplicationToken(ctx context.Context, appToken string) error {
	cacheKey := fmt.Sprintf("application:%s", appToken)
	_, err := rdb.Get(ctx, cacheKey).Result()
	if err == redis.Nil {
		return fmt.Errorf("application not found")
	}
	return err
}

func handleValidationError(c *gin.Context, err error, appToken string) {
	if err.Error() == "application not found" {
		log.Printf("Cache miss: Application token %s not found", appToken)
		respondWithError(c, http.StatusNotFound, fmt.Sprintf("Application with token %s not found", appToken))
		return
	}
	log.Printf("Redis error while validating application: %v", err)
	respondWithError(c, http.StatusInternalServerError, "Internal server error")
}

func generateJID() (string, error) {
	jidBytes := make([]byte, jidByteLength)
	if _, err := rand.Read(jidBytes); err != nil {
		return "", fmt.Errorf("error generating JID: %w", err)
	}
	return hex.EncodeToString(jidBytes), nil
}

func enqueueSidekiqJob(ctx context.Context, job SidekiqJob) error {
	jobJSON, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("error serializing Sidekiq job to JSON: %w", err)
	}

	queueKey := fmt.Sprintf("queue:%s", job.Queue)
	if err := rdb.RPush(ctx, queueKey, jobJSON).Err(); err != nil {
		return fmt.Errorf("redis error while adding job to queue: %w", err)
	}

	return nil
}

func enqueueChatCreationJob(ctx context.Context, chat Chat) error {
	chatMap := map[string]interface{}{
		"number":            chat.Number,
		"application_token": chat.ApplicationToken,
		"timestamp":         chat.TimeStamp.Format(time.RFC3339Nano),
	}

	jid, err := generateJID()
	if err != nil {
		return err
	}

	job := SidekiqJob{
		Class:      sidekiqJobClassChatsConsumer,
		Args:       []interface{}{chatMap},
		Retry:      true,
		Queue:      sidekiqQueueChatsCreation,
		Jid:        jid,
		CreatedAt:  time.Now(),
		EnqueuedAt: time.Now(),
	}

	return enqueueSidekiqJob(ctx, job)
}

func enqueueMessageCreationJob(ctx context.Context, message Message) error {
	messageMap := map[string]interface{}{
		"number":            message.Number,
		"body":              message.Body,
		"chat_number":      message.ChatNumber,
		"application_token": message.ApplicationToken,
		"timestamp":         message.TimeStamp.Format(time.RFC3339Nano),
	}

	jid, err := generateJID()
	if err != nil {
		return err
	}

	job := SidekiqJob{
		Class:      sidekiqJobClassMessageCreator,
		Args:       []interface{}{messageMap},
		Retry:      true,
		Queue:      sidekiqQueueMessageCreation,
		Jid:        jid,
		CreatedAt:  time.Now(),
		EnqueuedAt: time.Now(),
	}

	return enqueueSidekiqJob(ctx, job)
}

func respondWithError(c *gin.Context, statusCode int, message string) {
	c.JSON(statusCode, ErrorResponse{Error: message})
}
