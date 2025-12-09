/**
 * PetPal Firebase Cloud Functions
 * Server-side XP calculation and anti-cheat system
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

admin.initializeApp();

const db = admin.firestore();
const app = express();
app.use(cors({ origin: true }));

// Rate limiting storage (in production, use Redis)
const rateLimitStore = new Map();

// ============================================================================
// MIDDLEWARE
// ============================================================================

/**
 * Verify Firebase ID Token from Authorization header
 */
const verifyToken = async (req, res, next) => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split('Bearer ')[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.user = decodedToken;
        next();
    } catch (error) {
        console.error('Token verification failed:', error);
        return res.status(401).json({ error: 'Unauthorized: Invalid token' });
    }
};

/**
 * Rate limiting middleware
 * Limits: 100 requests per minute per user
 */
const rateLimit = (req, res, next) => {
    const userId = req.user?.uid;
    if (!userId) return next();

    const now = Date.now();
    const windowMs = 60 * 1000; // 1 minute
    const maxRequests = 100;

    const userKey = `rate_${userId}`;
    const userRequests = rateLimitStore.get(userKey) || [];

    // Filter requests within the window
    const recentRequests = userRequests.filter(timestamp => now - timestamp < windowMs);

    if (recentRequests.length >= maxRequests) {
        return res.status(429).json({
            error: 'Too many requests',
            retryAfter: Math.ceil((recentRequests[0] + windowMs - now) / 1000)
        });
    }

    recentRequests.push(now);
    rateLimitStore.set(userKey, recentRequests);

    next();
};

// ============================================================================
// XP CALCULATION CONFIG
// ============================================================================

const XP_CONFIG = {
    // Action XP values
    ACTIONS: {
        'meal': 15,
        'walk': 1, // per minute, calculated server-side
        'photo': 20,
        'task_complete': 10,
        'avatar_tap': 5,
        'avatar_bond': 10,
    },

    // Daily limits
    DAILY_LIMITS: {
        'meal': 10,        // Max 10 meals per day
        'walk': 5,         // Max 5 walks per day
        'photo': 20,       // Max 20 photos per day
        'task_complete': 50,
        'avatar_tap': 20,
        'avatar_bond': 10,
        'total_xp': 500,   // Max 500 XP per day
    },

    // Max XP per single action
    MAX_XP_PER_ACTION: 100,

    // Walk verification requirements
    WALK_VERIFICATION: {
        minPositions: 3,      // Minimum GPS points
        minDistance: 50,      // Minimum meters
        minSpeedMpm: 20,      // Min meters per minute (slow walk)
        maxSpeedMpm: 150,     // Max meters per minute (running)
    }
};

// ============================================================================
// API ENDPOINTS
// ============================================================================

/**
 * Add XP with server-side validation
 * POST /addXP
 * Body: { dogId: string, action: string, metadata?: object }
 */
app.post('/addXP', verifyToken, rateLimit, async (req, res) => {
    try {
        const { dogId, action, metadata = {} } = req.body;
        const userId = req.user.uid;

        if (!dogId || !action) {
            return res.status(400).json({ error: 'Missing dogId or action' });
        }

        // Verify dog belongs to user
        const dogRef = db.collection('users').doc(userId).collection('dogs').doc(dogId);
        const dogDoc = await dogRef.get();

        if (!dogDoc.exists) {
            return res.status(403).json({ error: 'Dog not found or access denied' });
        }

        // Get current gamification data
        const gamificationRef = dogRef.collection('gamification').doc('progress');
        const gamificationDoc = await gamificationRef.get();
        const gamification = gamificationDoc.exists ? gamificationDoc.data() : {};

        // Check daily limits
        const today = new Date().toISOString().split('T')[0];
        const lastDate = gamification.lastXPDate;

        let dailyCounts = {
            dailyXP: 0,
            dailyMeals: 0,
            dailyWalks: 0,
            dailyPhotos: 0,
            dailyTasks: 0,
            dailyTaps: 0,
            dailyBonds: 0,
        };

        if (lastDate === today) {
            dailyCounts = {
                dailyXP: gamification.dailyXP || 0,
                dailyMeals: gamification.dailyMeals || 0,
                dailyWalks: gamification.dailyWalks || 0,
                dailyPhotos: gamification.dailyPhotos || 0,
                dailyTasks: gamification.dailyTasks || 0,
                dailyTaps: gamification.dailyTaps || 0,
                dailyBonds: gamification.dailyBonds || 0,
            };
        }

        // Check action-specific limits
        const limits = XP_CONFIG.DAILY_LIMITS;

        if (action === 'meal' && dailyCounts.dailyMeals >= limits.meal) {
            return res.status(429).json({ error: 'Daily meal limit reached', limit: limits.meal });
        }
        if (action === 'walk' && dailyCounts.dailyWalks >= limits.walk) {
            return res.status(429).json({ error: 'Daily walk limit reached', limit: limits.walk });
        }
        if (action === 'photo' && dailyCounts.dailyPhotos >= limits.photo) {
            return res.status(429).json({ error: 'Daily photo limit reached', limit: limits.photo });
        }

        // Calculate XP
        let xpToAdd = XP_CONFIG.ACTIONS[action] || 0;

        // Special calculation for walks based on duration
        if (action === 'walk' && metadata.durationMinutes) {
            xpToAdd = Math.min(metadata.durationMinutes, 60); // Cap at 60 XP for walks

            // Verify walk if GPS data provided
            if (metadata.walkStats) {
                const { distanceMeters, positionCount, durationMinutes } = metadata.walkStats;
                const config = XP_CONFIG.WALK_VERIFICATION;

                const isVerified = (
                    positionCount >= config.minPositions &&
                    distanceMeters >= config.minDistance
                );

                if (!isVerified) {
                    xpToAdd = Math.floor(xpToAdd * 0.5); // 50% XP for unverified walks
                    metadata.verified = false;
                } else {
                    // Bonus XP for verified walks
                    xpToAdd += Math.floor(distanceMeters / 100); // +1 XP per 100m
                    metadata.verified = true;
                }
            }
        }

        // Cap XP per action
        xpToAdd = Math.min(xpToAdd, XP_CONFIG.MAX_XP_PER_ACTION);

        // Check total daily XP limit
        if (dailyCounts.dailyXP + xpToAdd > limits.total_xp) {
            xpToAdd = Math.max(0, limits.total_xp - dailyCounts.dailyXP);
        }

        if (xpToAdd <= 0) {
            return res.status(429).json({ error: 'Daily XP limit reached', limit: limits.total_xp });
        }

        // Calculate new XP and level
        const currentXP = gamification.currentXP || 0;
        const currentLevel = gamification.level || 1;
        let xpForNextLevel = gamification.xpForNextLevel || 1000;

        let newXP = currentXP + xpToAdd;
        let newLevel = currentLevel;

        while (newXP >= xpForNextLevel) {
            newXP -= xpForNextLevel;
            newLevel++;
            xpForNextLevel = 1000 + (newLevel * 200);
        }

        // Update daily counts
        if (action === 'meal') dailyCounts.dailyMeals++;
        if (action === 'walk') dailyCounts.dailyWalks++;
        if (action === 'photo') dailyCounts.dailyPhotos++;
        if (action === 'task_complete') dailyCounts.dailyTasks++;
        if (action === 'avatar_tap') dailyCounts.dailyTaps++;
        if (action === 'avatar_bond') dailyCounts.dailyBonds++;
        dailyCounts.dailyXP += xpToAdd;

        // Save to Firestore
        await gamificationRef.set({
            level: newLevel,
            currentXP: newXP,
            xpForNextLevel: xpForNextLevel,
            totalXP: (gamification.totalXP || 0) + xpToAdd,
            ...dailyCounts,
            lastXPDate: today,
            lastXPAction: action,
            lastXPMetadata: metadata,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Log action for audit
        await dogRef.collection('xp_log').add({
            action,
            xpAdded: xpToAdd,
            metadata,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            verified: metadata.verified ?? false,
        });

        res.json({
            success: true,
            xpAdded: xpToAdd,
            newXP,
            newLevel,
            xpForNextLevel,
            leveledUp: newLevel > currentLevel,
            dailyRemaining: limits.total_xp - dailyCounts.dailyXP,
        });

    } catch (error) {
        console.error('Error adding XP:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * Get XP status and daily limits
 * GET /xpStatus/:dogId
 */
app.get('/xpStatus/:dogId', verifyToken, async (req, res) => {
    try {
        const { dogId } = req.params;
        const userId = req.user.uid;

        const gamificationRef = db.collection('users').doc(userId)
            .collection('dogs').doc(dogId)
            .collection('gamification').doc('progress');

        const doc = await gamificationRef.get();

        if (!doc.exists) {
            return res.json({
                level: 1,
                currentXP: 0,
                xpForNextLevel: 1000,
                totalXP: 0,
                dailyXP: 0,
                dailyRemaining: XP_CONFIG.DAILY_LIMITS.total_xp,
            });
        }

        const data = doc.data();
        const today = new Date().toISOString().split('T')[0];
        const dailyXP = data.lastXPDate === today ? (data.dailyXP || 0) : 0;

        res.json({
            level: data.level || 1,
            currentXP: data.currentXP || 0,
            xpForNextLevel: data.xpForNextLevel || 1000,
            totalXP: data.totalXP || 0,
            dailyXP,
            dailyRemaining: XP_CONFIG.DAILY_LIMITS.total_xp - dailyXP,
            streak: data.streak || 0,
        });

    } catch (error) {
        console.error('Error getting XP status:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * Verify walk with GPS data
 * POST /verifyWalk
 */
app.post('/verifyWalk', verifyToken, rateLimit, async (req, res) => {
    try {
        const { dogId, walkData } = req.body;
        const userId = req.user.uid;

        const { distanceMeters, durationMinutes, positionCount, positions } = walkData;

        // Verify requirements
        const config = XP_CONFIG.WALK_VERIFICATION;

        const meetsMinPositions = positionCount >= config.minPositions;
        const meetsMinDistance = distanceMeters >= config.minDistance;

        // Calculate average speed
        const avgSpeedMpm = durationMinutes > 0 ? distanceMeters / durationMinutes : 0;
        const validSpeed = avgSpeedMpm >= config.minSpeedMpm && avgSpeedMpm <= config.maxSpeedMpm;

        const isVerified = meetsMinPositions && meetsMinDistance && (durationMinutes < 5 || validSpeed);

        // Calculate XP
        let xp = durationMinutes;
        if (isVerified) {
            xp += Math.floor(distanceMeters / 100); // Distance bonus
        } else {
            xp = Math.floor(xp * 0.5); // Penalty for unverified
        }

        xp = Math.min(xp, XP_CONFIG.MAX_XP_PER_ACTION);

        res.json({
            verified: isVerified,
            xpEarned: xp,
            stats: {
                distanceMeters,
                durationMinutes,
                positionCount,
                avgSpeedMpm: avgSpeedMpm.toFixed(1),
            },
            checks: {
                minPositions: meetsMinPositions,
                minDistance: meetsMinDistance,
                validSpeed: durationMinutes < 5 ? true : validSpeed,
            }
        });

    } catch (error) {
        console.error('Error verifying walk:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Export the Express app as a Firebase Function
exports.api = functions.https.onRequest(app);

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

/**
 * Reset daily counters at midnight (runs daily at 00:00 UTC)
 */
exports.resetDailyCounters = functions.pubsub
    .schedule('0 0 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        console.log('Resetting daily counters...');
        // Counters auto-reset when lastXPDate doesn't match today
        // This is handled in the addXP endpoint
        return null;
    });

/**
 * Update streaks daily
 */
exports.updateStreaks = functions.pubsub
    .schedule('0 1 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        console.log('Updating streaks...');

        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];

        // Find all users with activity yesterday and update their streaks
        // This is a simplified version - in production, use batched writes

        return null;
    });
