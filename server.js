const newrelic = require("newrelic");
const express = require("express");
const logger = require('./src/lib/logger');

newrelic.instrumentLoadedModule("express", express);

const app = express();
const path = require("path");
const router = express.Router();
const bodyParser = require("body-parser");
const cors = require("cors");
const { chaos } = require("express-chaos-middleware");
const { GameplayAnalyzer } = require('./gameplayanalyzer');

// Chaos Monkey (from your original setup)
// app.use(chaos({
//     probability: 20,
//     maxDelay: 2000,
// }));

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "/src")));

// Initialize AI gameplay analyzer
const analyzer = new GameplayAnalyzer(logger);

// Game state storage
const gameSessions = new Map();
const playerStats = new Map();

// Your original routes
router.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "/src/index.html"));  
});

app.get("/game", (req, res) => {
    logger.info("Game route accessed");
    res.sendFile(path.join(__dirname, "/src/index.html"));  
});

app.get("/score", (req, res) => {
    let score = Math.floor(Math.random() * (30000 - 10000) + 10000);
    let id = Math.floor(Math.random() * (30 - 1) + 1);

    logger.info(`Score request - Player ${id} scored ${score}`);
    res.status(200).send(`Player ${id} - ${score}`);
});

app.get("/404", (req, res) => {
    logger.warn("Warning at /404");
    logger.warn(`${req.method} ${req.path} from ${req.hostname}`);
    res.sendStatus(404);
});

app.get("/user", (req, res) => {
    try {
        throw new Error("Error! Invalid user!");
    } catch (error) {
        logger.error("Invalid user at /user");
        logger.error(`${req.method} ${req.path} from ${req.hostname}`);
        res.status(500).send("Error! Invalid user!");
    }
});

// AI-powered game session endpoints
app.post('/api/ai/game/start', async (req, res) => {
    try {
        const { playerId } = req.body;
        const sessionId = `ai_session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        
        gameSessions.set(sessionId, {
            playerId,
            startTime: Date.now(),
            actions: [],
            metrics: {
                totalActions: 0,
                averageReactionTime: 0,
                accuracy: 0,
                streakCount: 0,
                maxStreak: 0
            }
        });
        
        logger.info('AI Game session started', {
            sessionId,
            playerId,
            timestamp: new Date().toISOString()
        });
        
        res.json({ sessionId, message: 'AI-powered game session started' });
        
    } catch (error) {
        logger.error('Failed to start AI game session', {
            error: error.message,
            stack: error.stack
        });
        res.status(500).json({ error: 'Failed to start session' });
    }
});

// Real-time AI action analysis
app.post('/api/ai/game/action', async (req, res) => {
    try {
        const { sessionId, action } = req.body;
        const session = gameSessions.get(sessionId);
        
        if (!session) {
            logger.warn('Session not found', { sessionId });
            return res.status(404).json({ error: 'Session not found' });
        }
        
        const actionData = {
            ...action,
            timestamp: Date.now(),
            sequence: session.actions.length + 1
        };
        
        session.actions.push(actionData);
        session.metrics.totalActions++;
        
        // AI-powered real-time analysis
        const realtimeAnalysis = await analyzer.analyzeRealtime(actionData, session);
        
        logger.info('AI action analysis completed', {
            sessionId,
            playerId: session.playerId,
            actionType: action.type,
            performance: realtimeAnalysis.performance,
            streak: realtimeAnalysis.streak,
            timestamp: new Date().toISOString()
        });
        
        res.json({
            analysis: realtimeAnalysis,
            sessionMetrics: session.metrics
        });
        
    } catch (error) {
        logger.error('AI action analysis failed', {
            error: error.message,
            stack: error.stack,
            sessionId: req.body.sessionId
        });
        res.status(500).json({ error: 'Analysis failed' });
    }
});

// End AI game session with full analysis
app.post('/api/ai/game/end', async (req, res) => {
    try {
        const { sessionId } = req.body;
        const session = gameSessions.get(sessionId);
        
        if (!session) {
            logger.warn('Session not found for end analysis', { sessionId });
            return res.status(404).json({ error: 'Session not found' });
        }
        
        session.endTime = Date.now();
        session.duration = session.endTime - session.startTime;
        
        // Run comprehensive AI analysis
        const fullAnalysis = await analyzer.analyzeFullSession(session);
        
        // Update player stats
        const playerId = session.playerId;
        if (!playerStats.has(playerId)) {
            playerStats.set(playerId, {
                totalSessions: 0,
                averageScore: 0,
                skillProgression: [],
                playStyle: 'unknown'
            });
        }
        
        const playerData = playerStats.get(playerId);
        playerData.totalSessions++;
        playerData.skillProgression.push(fullAnalysis.skillAssessment);
        playerData.playStyle = fullAnalysis.playStyle;
        
        logger.info('AI Full Analysis Completed', {
            sessionId,
            playerId,
            skillLevel: fullAnalysis.skillAssessment,
            playStyle: fullAnalysis.playStyle,
            score: fullAnalysis.score,
            confidence: fullAnalysis.confidence,
            duration: session.duration,
            totalActions: session.metrics.totalActions,
            timestamp: new Date().toISOString()
        });
        
        // Clean up session data
        gameSessions.delete(sessionId);
        
        res.json({
            sessionAnalysis: fullAnalysis,
            playerStats: playerData
        });
        
    } catch (error) {
        logger.error('AI full analysis failed', {
            error: error.message,
            stack: error.stack,
            sessionId: req.body.sessionId
        });
        
        // Attempt fallback analysis
        const session = gameSessions.get(req.body.sessionId);
        const fallbackAnalysis = session ? analyzer.getFallbackAnalysis(session) : null;
        
        res.status(500).json({ 
            error: 'AI analysis failed', 
            fallback: fallbackAnalysis
        });
    }
});

// Get AI-enhanced player analytics
app.get('/api/ai/player/:playerId/stats', (req, res) => {
    try {
        const { playerId } = req.params;
        const stats = playerStats.get(playerId) || {};
        
        logger.info('Player stats requested', {
            playerId,
            totalSessions: stats.totalSessions,
            timestamp: new Date().toISOString()
        });
        
        res.json(stats);
        
    } catch (error) {
        logger.error('Player stats request failed', {
            error: error.message,
            stack: error.stack,
            playerId: req.params.playerId
        });
        res.status(500).json({ error: 'Failed to retrieve stats' });
    }
});

// AI system health check
app.get('/api/ai/health', (req, res) => {
    try {
        const systemHealth = {
            status: 'ok',
            ollamaStatus: analyzer.getStatus(),
            memory: process.memoryUsage(),
            uptime: process.uptime(),
            activeSessions: gameSessions.size,
            totalPlayers: playerStats.size,
            timestamp: new Date().toISOString()
        };
        
        logger.info('AI system health check', systemHealth);
        res.json(systemHealth);
        
    } catch (error) {
        logger.error('Health check failed', {
            error: error.message,
            stack: error.stack
        });
        res.status(500).json({ error: 'Health check failed' });
    }
});

// Use original router and start server
app.use("/", router);
app.listen(process.env.port || 3000);

logger.info("Starting the AI-enhanced game server", {
    port: process.env.port || 3000,
    timestamp: new Date().toISOString()
});