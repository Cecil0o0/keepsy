CREATE TABLE if not exists memory (
    id INTEGER primary key autoincrement,
    uid TEXT,
    llm_id TEXT,
    agent_id TEXT,
    immutable boolean,
    category TEXT,
    content TEXT,
    created_at TEXT,
    updated_at TEXT
)

CREATE TABLE if not exists feedback (
    memory_id INTEGER,
    helpfulness INTEGER,
    content TEXT,
)