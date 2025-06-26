const winston = require('winston');
const path = require('path');

// Define log format
const logFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
);

// Create logger instance
const logger = winston.createLogger({
    level: 'info',
    format: logFormat,
    defaultMeta: { service: 'ai-game-analyzer' },
    transports: [
        // Console transport
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.simple()
            )
        }),
        // File transport for all logs
        new winston.transports.File({ 
            filename: path.join(__dirname, '../../logs/combined.log')
        }),
        // File transport for error logs
        new winston.transports.File({ 
            filename: path.join(__dirname, '../../logs/error.log'),
            level: 'error'
        }),
        // File transport specifically for AI analysis
        new winston.transports.File({ 
            filename: path.join(__dirname, '../../logs/ai-analysis.log'),
            level: 'info'
        })
    ]
});

// Create a stream object for Morgan
logger.stream = {
    write: function(message) {
        logger.info(message.trim());
    }
};

module.exports = logger; 