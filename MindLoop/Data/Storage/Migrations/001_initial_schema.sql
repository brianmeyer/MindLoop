-- Migration 001: Initial Schema
-- Creates tables for journal entries, emotions, and CBT cards
-- Version: 1.0
-- Date: 2025-10-26

-- Journal Entries table
CREATE TABLE IF NOT EXISTS journal_entries (
    id TEXT PRIMARY KEY NOT NULL,
    timestamp REAL NOT NULL,  -- Unix timestamp (seconds since 1970)
    text TEXT NOT NULL,
    
    -- Emotion data (denormalized for query performance)
    emotion_label TEXT NOT NULL,
    emotion_confidence REAL NOT NULL,
    emotion_valence REAL NOT NULL,
    emotion_arousal REAL NOT NULL,
    
    -- Tags (comma-separated for SQLite simplicity)
    tags TEXT,  -- e.g., "work,stress,presentation"
    
    -- Metadata
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Index for timestamp-based queries (recent entries)
CREATE INDEX IF NOT EXISTS idx_entries_timestamp ON journal_entries(timestamp DESC);

-- Index for emotion label filtering
CREATE INDEX IF NOT EXISTS idx_entries_emotion ON journal_entries(emotion_label);

-- Full-text search index (for BM25)
CREATE VIRTUAL TABLE IF NOT EXISTS journal_entries_fts USING fts5(
    id UNINDEXED,
    text,
    tags,
    content=journal_entries,
    content_rowid=rowid
);

-- Trigger to keep FTS index in sync
CREATE TRIGGER IF NOT EXISTS journal_entries_ai AFTER INSERT ON journal_entries BEGIN
    INSERT INTO journal_entries_fts(rowid, id, text, tags)
    VALUES (new.rowid, new.id, new.text, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS journal_entries_ad AFTER DELETE ON journal_entries BEGIN
    DELETE FROM journal_entries_fts WHERE rowid = old.rowid;
END;

CREATE TRIGGER IF NOT EXISTS journal_entries_au AFTER UPDATE ON journal_entries BEGIN
    UPDATE journal_entries_fts 
    SET text = new.text, tags = new.tags 
    WHERE rowid = new.rowid;
END;

-- Vector embeddings table (separate for performance)
-- Stores 462-dimensional embeddings from Qwen3-Embedding-0.6B
CREATE TABLE IF NOT EXISTS embeddings (
    entry_id TEXT PRIMARY KEY NOT NULL,
    embedding_type TEXT NOT NULL,  -- 'qwen3' (single model)
    vector BLOB NOT NULL,  -- Float array serialized to bytes
    dimension INTEGER NOT NULL DEFAULT 462,
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now')),

    FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
);

-- Index for embedding type filtering
CREATE INDEX IF NOT EXISTS idx_embeddings_type ON embeddings(embedding_type);

-- Prosody features table (from OpenSMILE)
-- Stores raw prosody features per entry
CREATE TABLE IF NOT EXISTS prosody_features (
    entry_id TEXT PRIMARY KEY NOT NULL,
    pitch_mean REAL,
    pitch_std REAL,
    pitch_range REAL,
    energy_mean REAL,
    energy_std REAL,
    speaking_rate REAL,
    pause_count INTEGER,
    pause_duration REAL,
    
    -- Store full feature set as JSON for extensibility
    full_features TEXT,  -- JSON object with 6k+ features
    
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now')),
    
    FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
);

-- CBT Cards table (static library)
CREATE TABLE IF NOT EXISTS cbt_cards (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL,
    technique TEXT NOT NULL,
    example TEXT NOT NULL,
    distortion_type TEXT,  -- NULL if general technique
    difficulty TEXT NOT NULL DEFAULT 'beginner',  -- 'beginner', 'intermediate', 'advanced'
    
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Index for distortion type filtering
CREATE INDEX IF NOT EXISTS idx_cards_distortion ON cbt_cards(distortion_type);

-- Coach Responses table (for learning loop analysis)
CREATE TABLE IF NOT EXISTS coach_responses (
    id TEXT PRIMARY KEY NOT NULL,
    entry_id TEXT NOT NULL,
    text TEXT NOT NULL,
    timestamp REAL NOT NULL,
    
    -- Cited entries (comma-separated IDs)
    cited_entries TEXT,
    
    suggested_action TEXT,
    next_state TEXT NOT NULL,
    
    -- Metadata (stored as JSON for flexibility)
    metadata TEXT NOT NULL,  -- JSON: tokenCount, latencyMs, model, loraAdapter, retrievalContext
    
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now')),
    
    FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
);

-- Index for entry_id lookup
CREATE INDEX IF NOT EXISTS idx_responses_entry ON coach_responses(entry_id);

-- Index for timestamp (recent responses)
CREATE INDEX IF NOT EXISTS idx_responses_timestamp ON coach_responses(timestamp DESC);

-- Personalization Profile table (single row per user)
CREATE TABLE IF NOT EXISTS personalization_profiles (
    id TEXT PRIMARY KEY NOT NULL DEFAULT 'default',
    last_updated REAL NOT NULL,
    
    tone_pref TEXT NOT NULL DEFAULT 'warm',
    response_length TEXT NOT NULL DEFAULT 'medium',
    
    -- Arrays stored as comma-separated values
    emotion_triggers TEXT,  -- e.g., "work_stress,sleep_rumination"
    avoid_topics TEXT,
    preferred_actions TEXT,  -- e.g., "reframing,breathing,mindfulness"
    
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Learning Loop feedback table (for DPO export)
CREATE TABLE IF NOT EXISTS feedback_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    response_id TEXT NOT NULL,
    entry_id TEXT NOT NULL,
    
    feedback_type TEXT NOT NULL,  -- 'thumbs_up', 'thumbs_down', 'edit', 'skip'
    
    -- For edits: store original and edited text
    original_text TEXT,
    edited_text TEXT,
    
    timestamp REAL NOT NULL,
    
    FOREIGN KEY (response_id) REFERENCES coach_responses(id) ON DELETE CASCADE,
    FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
);

-- Index for response_id lookup
CREATE INDEX IF NOT EXISTS idx_feedback_response ON feedback_log(response_id);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY NOT NULL,
    applied_at REAL NOT NULL DEFAULT (strftime('%s', 'now')),
    description TEXT
);

-- Insert initial version
INSERT OR IGNORE INTO schema_version (version, description) 
VALUES (1, 'Initial schema with journal entries, embeddings, prosody, CBT cards, coach responses, personalization, and feedback log');
