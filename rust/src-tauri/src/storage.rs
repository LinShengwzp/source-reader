use rusqlite::{Connection, Result};

pub struct User {
    id: u32,
    name: String,
    email: String
}

fn create() -> Result<()> {
    let conn = Connection::open("path/to/database.db")?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL
        )",
        [],
    )?;

    conn.execute(
        "INSERT INTO users (name, email) VALUES (?1, ?2)",
        ["John Doe", "john@example.com"],
    )?;

    let mut stmt = conn.prepare("SELECT * FROM users")?;
    let rows = stmt.query_map([], |row| {
        Ok(User {
            id: row.get(0)?,
            name: row.get(1)?,
            email: row.get(2)?,
        })
    })?;

    for row in rows {
        // println!("{:?}", row?);
    }

    Ok(())
}
