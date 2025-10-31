-- Migration 002: Chunk-Aware Embeddings
-- Migrates embeddings table to support semantic chunks for long journal entries
-- Version: 1.1
-- Date: 2025-10-27

-- Step 1: Rename old embeddings table
ALTER TABLE embeddings RENAME TO embeddings_old;

-- Step 2: Create new chunk-aware embeddings table
CREATE TABLE IF NOT EXISTS embeddings (
    -- Chunk identifier: "entry-{parentId}_chunk-{index}"
    id TEXT PRIMARY KEY NOT NULL,

    -- Parent entry reference
    parent_entry_id TEXT NOT NULL,

    -- Chunk index within parent entry (0-based)
    chunk_index INTEGER NOT NULL DEFAULT 0,

    -- Chunk text content
    text TEXT NOT NULL,

    -- Embedding vector (462-dim from Qwen3-Embedding-0.6B)
    vector BLOB NOT NULL,
    dimension INTEGER NOT NULL DEFAULT 462,

    -- Audio timing (seconds from entry start)
    -- NULL for text-only entries
    start_time REAL,
    end_time REAL,

    -- Aggregate emotion for chunk
    emotion_label TEXT NOT NULL,
    emotion_confidence REAL NOT NULL,
    emotion_valence REAL NOT NULL,
    emotion_arousal REAL NOT NULL,

    -- Aggregate prosody features
    -- NULL when prosody data unavailable
    avg_pitch REAL,
    avg_energy REAL,
    avg_speaking_rate REAL,

    -- Token count (used for chunking algorithm)
    token_count INTEGER NOT NULL,

    -- Metadata
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now')),

    FOREIGN KEY (parent_entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
);

-- Step 3: Migrate existing embeddings to new schema
-- Old embeddings become chunk-0 of their parent entry
INSERT INTO embeddings (
    id,
    parent_entry_id,
    chunk_index,
    text,
    vector,
    dimension,
    start_time,
    end_time,
    emotion_label,
    emotion_confidence,
    emotion_valence,
    emotion_arousal,
    avg_pitch,
    avg_energy,
    avg_speaking_rate,
    token_count,
    created_at
)
SELECT
    -- Generate chunk ID: entry_id becomes entry-{id}_chunk-0
    old.entry_id || '_chunk-0' AS id,

    -- Parent reference
    old.entry_id AS parent_entry_id,

    -- First chunk
    0 AS chunk_index,

    -- Get text from journal entry
    je.text AS text,

    -- Existing embedding vector
    old.vector,
    old.dimension,

    -- No timing for migrated entries
    NULL AS start_time,
    NULL AS end_time,

    -- Copy emotion from journal entry
    je.emotion_label,
    je.emotion_confidence,
    je.emotion_valence,
    je.emotion_arousal,

    -- Copy prosody if available
    pf.pitch_mean AS avg_pitch,
    pf.energy_mean AS avg_energy,
    pf.speaking_rate AS avg_speaking_rate,

    -- Estimate tokens from word count
    -- Rough estimate: word_count / 0.75
    CAST(
        (LENGTH(je.text) - LENGTH(REPLACE(je.text, ' ', '')) + 1) / 0.75
        AS INTEGER
    ) AS token_count,

    old.created_at
FROM embeddings_old old
INNER JOIN journal_entries je ON old.entry_id = je.id
LEFT JOIN prosody_features pf ON old.entry_id = pf.entry_id;

-- Step 4: Drop old table
DROP TABLE embeddings_old;

-- Step 5: Create indexes for chunk queries
CREATE INDEX IF NOT EXISTS idx_embeddings_parent ON embeddings(parent_entry_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_emotion ON embeddings(emotion_label);
CREATE INDEX IF NOT EXISTS idx_embeddings_parent_chunk ON embeddings(parent_entry_id, chunk_index);

-- Step 6: Update schema version
INSERT INTO schema_version (version, description)
VALUES (2, 'Chunk-aware embeddings with emotion and prosody metadata per chunk');
