import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { Pool } from 'pg'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const schemaPath = path.join(__dirname, 'schema.sql')

const connectionString =
  process.env.DATABASE_URL || 'postgres://postgres:postgres@127.0.0.1:5432/chkela'

export const pool = new Pool({
  connectionString,
  max: Number(process.env.PG_POOL_MAX || 20),
})

export async function migrateSchema() {
  const sql = fs.readFileSync(schemaPath, 'utf8')
  await pool.query(sql)
}

export async function tx(work) {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    const out = await work(client)
    await client.query('COMMIT')
    return out
  } catch (error) {
    await client.query('ROLLBACK')
    throw error
  } finally {
    client.release()
  }
}

