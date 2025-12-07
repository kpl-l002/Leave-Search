package storage

import (
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type CrawlTask struct {
	ID        uint      `gorm:"primaryKey"`
	URL       string    `gorm:"uniqueIndex;not null"`
	Status    string    `gorm:"default:'pending'"` // pending, processing, completed, failed
	Retry     int       `gorm:"default:0"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

type PageResult struct {
	ID        uint      `gorm:"primaryKey"`
	URL       string    `gorm:"uniqueIndex;not null"`
	Title     string
	Content   string
	CreatedAt time.Time
}

type ErrorLog struct {
	ID        uint      `gorm:"primaryKey"`
	TaskID    uint
	Message   string
	CreatedAt time.Time
}

type DB struct {
	db *gorm.DB
}

func NewDB(dsn string) (*DB, error) {
	// Using SQLite for simplicity, can be swapped with MySQL/PostgreSQL
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
	if err != nil {
		return nil, err
	}

	// Auto Migrate
	err = db.AutoMigrate(&CrawlTask{}, &PageResult{}, &ErrorLog{})
	if err != nil {
		return nil, err
	}

	return &DB{db: db}, nil
}

func (d *DB) AddTask(url string) error {
	task := CrawlTask{URL: url}
	return d.db.Create(&task).Error
}

func (d *DB) GetPendingTasks(limit int) ([]CrawlTask, error) {
	var tasks []CrawlTask
	err := d.db.Where("status = ?", "pending").Limit(limit).Find(&tasks).Error
	return tasks, err
}

func (d *DB) SaveResult(result *PageResult) error {
	return d.db.Save(result).Error
}

func (d *DB) LogError(taskID uint, msg string) {
	d.db.Create(&ErrorLog{TaskID: taskID, Message: msg})
}
