const axios = require('axios');

class GameplayAnalyzer {
    constructor(logger) {
        this.logger = logger;
        this.ollamaUrl = process.env.OLLAMA_URL || 'http://localhost:11434';
        this.modelName = process.env.OLLAMA_MODEL || 'tinyllama';
        this.isInitialized = false;
        this.analysisQueue = [];
        this.maxQueueSize = 5;
        
        this.init();
    }
    
    async init() {
        try {
            await axios.get(`${this.ollamaUrl}/api/tags`, { timeout: 5000 });
            this.logger.info('✅ Ollama connection established');
            await this.loadModel();
            this.isInitialized = true;
        } catch (error) {
            this.logger.warn('⚠️ Ollama not available, using fallback analysis');
            this.isInitialized = false;
        }
    }
    
    async loadModel() {
        try {
            const response = await axios.post(`${this.ollamaUrl}/api/generate`, {
                model: this.modelName,
                prompt: "Hi",
                stream: false
            }, { timeout: 30000 });
            
            this.logger.info(`✅ Model ${this.modelName} loaded successfully`);
        } catch (error) {
            this.logger.error('Failed to load model:', error.message);
            throw error;
        }
    }
    
    async analyzeRealtime(action, session) {
        if (action.type !== 'missile_shot') {
            return null;
        }

        const realtimeMetrics = this.calculateMissileMetrics(action, session);
        
        if (this.analysisQueue.length < this.maxQueueSize) {
            this.analysisQueue.push({ 
                action: {
                    type: action.type,
                    success: action.success,
                    timestamp: action.timestamp,
                    targetDistance: action.targetDistance,
                    missileSpeed: action.missileSpeed
                }, 
                sessionId: session.sessionId 
            });
        }
        
        return {
            accuracy: realtimeMetrics.accuracy,
            targetDistance: realtimeMetrics.targetDistance,
            missileSpeed: realtimeMetrics.missileSpeed,
            hitRate: realtimeMetrics.hitRate,
            averageResponseTime: realtimeMetrics.averageResponseTime
        };
    }
    
    calculateMissileMetrics(action, session) {
        const missileActions = session.actions.filter(a => a.type === 'missile_shot');
        const totalShots = missileActions.length;
        const successfulHits = missileActions.filter(a => a.success).length;
        
        return {
            accuracy: action.success ? 1 : 0,
            targetDistance: action.targetDistance || 0,
            missileSpeed: action.missileSpeed || 0,
            hitRate: totalShots > 0 ? (successfulHits / totalShots) * 100 : 0,
            averageResponseTime: this.calculateAverageResponseTime(missileActions)
        };
    }
    
    calculateAverageResponseTime(actions) {
        if (actions.length < 2) return 0;
        
        let totalTime = 0;
        let count = 0;
        
        for (let i = 1; i < actions.length; i++) {
            totalTime += actions[i].timestamp - actions[i-1].timestamp;
            count++;
        }
        
        return Math.round(totalTime / count);
    }
    
    async analyzeFullSession(session) {
        if (!this.isInitialized) {
            this.logger.info('Using fallback analysis (Ollama not available)');
            return this.getFallbackMissileAnalysis(session);
        }
        
        try {
            const prompt = this.buildMissileAnalysisPrompt(session);
            const aiAnalysis = await this.queryOllama(prompt);
            
            const fallbackAnalysis = this.getFallbackMissileAnalysis(session);
            
            return {
                ...fallbackAnalysis,
                aiInsights: aiAnalysis,
                confidence: 'high'
            };
            
        } catch (error) {
            this.logger.error('AI analysis failed, using fallback:', error.message);
            return this.getFallbackMissileAnalysis(session);
        }
    }
    
    buildMissileAnalysisPrompt(session) {
        const missileActions = session.actions.filter(a => a.type === 'missile_shot');
        const gameData = {
            duration: Math.round(session.duration / 1000),
            totalShots: missileActions.length,
            hitRate: missileActions.filter(a => a.success).length / missileActions.length,
            averageResponseTime: this.calculateAverageResponseTime(missileActions),
            averageTargetDistance: this.calculateAverageTargetDistance(missileActions)
        };
        
        return `Missile shooting analysis:
Game Duration: ${gameData.duration} seconds
Total Shots: ${gameData.totalShots}
Hit Rate: ${(gameData.hitRate * 100).toFixed(1)}%
Average Response Time: ${gameData.averageResponseTime}ms
Average Target Distance: ${gameData.averageTargetDistance} units

Analyze the player's:
1. Shooting accuracy level (beginner/intermediate/advanced)
2. Shooting style (precise/rapid/balanced)
3. Main strength in missile combat
4. Improvement tip for missile accuracy

Be brief, under 100 words.`;
    }
    
    calculateAverageTargetDistance(actions) {
        if (actions.length === 0) return 0;
        const totalDistance = actions.reduce((sum, action) => sum + (action.targetDistance || 0), 0);
        return Math.round(totalDistance / actions.length);
    }
    
    getFallbackMissileAnalysis(session) {
        const missileActions = session.actions.filter(a => a.type === 'missile_shot');
        const hitRate = missileActions.filter(a => a.success).length / missileActions.length;
        const avgResponseTime = this.calculateAverageResponseTime(missileActions);
        
        return {
            skillLevel: this.assessMissileSkillLevel(hitRate, avgResponseTime),
            shootingStyle: this.determineShootingStyle(missileActions),
            strengths: this.identifyMissileStrengths(missileActions),
            improvements: this.suggestMissileImprovements(missileActions),
            score: Math.round(hitRate * 1000 + (this.calculateAverageTargetDistance(missileActions) * 10)),
            confidence: 'medium'
        };
    }
    
    assessMissileSkillLevel(hitRate, avgResponseTime) {
        if (hitRate > 0.8 && avgResponseTime < 300) return 'advanced';
        if (hitRate > 0.6 && avgResponseTime < 500) return 'intermediate';
        return 'beginner';
    }
    
    determineShootingStyle(actions) {
        const avgPause = this.calculateAveragePause(actions);
        
        if (avgPause < 200) return 'rapid';
        if (avgPause > 800) return 'precise';
        return 'balanced';
    }
    
    calculateAveragePause(actions) {
        if (actions.length < 2) return 0;
        
        const pauses = [];
        for (let i = 1; i < actions.length; i++) {
            pauses.push(actions[i].timestamp - actions[i-1].timestamp);
        }
        return pauses.reduce((a, b) => a + b, 0) / pauses.length;
    }
    
    identifyMissileStrengths(actions) {
        const strengths = [];
        const hitRate = actions.filter(a => a.success).length / actions.length;
        
        if (hitRate > 0.8) strengths.push('High accuracy');
        if (this.calculateAverageResponseTime(actions) < 250) {
            strengths.push('Quick target acquisition');
        }
        if (this.calculateAverageTargetDistance(actions) > 500) {
            strengths.push('Good long-range accuracy');
        }
        
        return strengths.length ? strengths : ['Room for improvement'];
    }
    
    suggestMissileImprovements(actions) {
        const suggestions = [];
        const hitRate = actions.filter(a => a.success).length / actions.length;
        const avgResponseTime = this.calculateAverageResponseTime(actions);
        
        if (hitRate < 0.5) suggestions.push('Focus on accuracy over speed');
        if (avgResponseTime > 600) suggestions.push('Work on faster target acquisition');
        if (this.calculateAverageTargetDistance(actions) < 300) {
            suggestions.push('Practice long-range shots');
        }
        
        return suggestions.length ? suggestions : ['Keep practicing!'];
    }
    
    getStatus() {
        return {
            initialized: this.isInitialized,
            model: this.modelName,
            queueLength: this.analysisQueue.length,
            url: this.ollamaUrl
        };
    }
}

module.exports = { GameplayAnalyzer };