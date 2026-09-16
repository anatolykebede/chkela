import fs from 'node:fs'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { isMutatingMethod, requireAdminRequest } from '../adminAuth.mjs'
import { sanitizeCmsPayload, scrubSvgBuffer } from '../sanitizeHtml.mjs'
import { createContentStore } from './store.mjs'

const ALLOWED_EXT = new Set([
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.svg',
  '.pdf',
  '.mp4',
  '.webm',
])

const MAX_UPLOAD_BYTES = 12 * 1024 * 1024

export function contentApiPlugin({ contentFile, assetsContentFile, assetsFiguresDir }) {
  const store = createContentStore(contentFile, {
    assetsFile: assetsContentFile,
    assetsFiguresDir,
  })
  const contentDir = path.dirname(path.resolve(contentFile))
  const uploadsDir = path.join(contentDir, 'uploads')
  const figuresDir = path.join(contentDir, 'figures')
  fs.mkdirSync(uploadsDir, { recursive: true })
  fs.mkdirSync(figuresDir, { recursive: true })

  return {
    name: 'chkela-content-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(store, uploadsDir, figuresDir))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(store, uploadsDir, figuresDir))
    },
  }
}

function apiMiddleware(store, uploadsDir, figuresDir) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    const isContentApi = rawUrl.startsWith('/api/content')
    const isUploadStatic = rawUrl.startsWith('/uploads/')
    const isFigureStatic = rawUrl.startsWith('/figures/')
    if (!isContentApi && !isUploadStatic && !isFigureStatic) {
      next()
      return
    }

    if (req.method === 'OPTIONS') {
      res.statusCode = 204
      cors(res)
      res.end()
      return
    }

    Promise.resolve()
      .then(async () => {
        const url = new URL(rawUrl, 'http://localhost')
        const pathname = url.pathname.replace(/\/$/, '') || '/'

        if (req.method === 'GET' && pathname.startsWith('/uploads/')) {
          serveStaticFile(res, uploadsDir, pathname)
          return
        }

        if (req.method === 'GET' && pathname.startsWith('/figures/')) {
          serveStaticFile(res, figuresDir, pathname)
          return
        }

        // Never allow directory listing of upload/figure roots.
        if (
          req.method === 'GET' &&
          (pathname === '/uploads' ||
            pathname === '/figures' ||
            pathname === '/uploads/' ||
            pathname === '/figures/')
        ) {
          sendJson(res, 404, { error: 'not_found' })
          return
        }

        if (isMutatingMethod(req.method) && pathname.startsWith('/api/content')) {
          if (!requireAdminRequest(req, res)) return
        }

        if (req.method === 'POST' && pathname === '/api/content/upload') {
          const body = await readBody(req)
          const saved = saveUpload(uploadsDir, body)
          sendJson(res, 201, saved)
          return
        }

        if (req.method === 'GET' && pathname === '/api/content') {
          sendJson(res, 200, { catalog: store.list() })
          return
        }

        const upsertMatch = pathname.match(/^\/api\/content\/([a-zA-Z]+)$/)
        if (req.method === 'POST' && upsertMatch) {
          const collection = upsertMatch[1]
          if (collection === 'upload') {
            sendJson(res, 404, { error: 'not_found' })
            return
          }
          const body = await readBody(req)
          const item = store.upsert(collection, sanitizeCmsPayload(body))
          sendJson(res, 201, { item })
          return
        }

        const deleteMatch = pathname.match(
          /^\/api\/content\/([a-zA-Z]+)\/([^/]+)$/,
        )
        if (req.method === 'DELETE' && deleteMatch) {
          const collection = deleteMatch[1]
          const id = decodeURIComponent(deleteMatch[2])
          const ok = store.remove(collection, id)
          sendJson(res, ok ? 200 : 404, ok ? { ok: true } : { error: 'not_found' })
          return
        }

        sendJson(res, 404, { error: 'not_found' })
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : 'Server error'
        sendJson(res, 400, { error: message })
      })
  }
}

function saveUpload(uploadsDir, body) {
  const filename = String(body.filename || 'file.bin')
  const ext = path.extname(filename).toLowerCase() || guessExt(body.contentType)
  if (!ALLOWED_EXT.has(ext)) {
    throw new Error(`Unsupported file type: ${ext || 'unknown'}`)
  }
  const dataUrl = String(body.data || '')
  const base64 = dataUrl.includes(',') ? dataUrl.split(',').pop() : dataUrl
  if (!base64) throw new Error('Missing file data')
  const bufferRaw = Buffer.from(base64, 'base64')
  if (!bufferRaw.length) throw new Error('Empty file')
  if (bufferRaw.length > MAX_UPLOAD_BYTES) {
    throw new Error('File too large (max 12MB)')
  }
  const buffer = ext === '.svg' ? scrubSvgBuffer(bufferRaw) : bufferRaw
  const safeBase = path
    .basename(filename, path.extname(filename))
    .replace(/[^a-zA-Z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40) || 'file'
  const storedName = `${safeBase}-${randomUUID().slice(0, 8)}${ext}`
  fs.writeFileSync(path.join(uploadsDir, storedName), buffer)
  return {
    url: `/uploads/${storedName}`,
    filename: storedName,
    bytes: buffer.length,
    contentType: body.contentType || mimeForExt(ext),
  }
}

function serveStaticFile(res, rootDir, pathname) {
  const name = path.basename(pathname)
  if (!name || name.includes('..')) {
    sendJson(res, 400, { error: 'invalid_path' })
    return
  }
  const filePath = path.join(rootDir, name)
  if (!fs.existsSync(filePath)) {
    sendJson(res, 404, { error: 'not_found' })
    return
  }
  const ext = path.extname(name).toLowerCase()
  const data = fs.readFileSync(filePath)
  res.statusCode = 200
  cors(res)
  res.setHeader('Content-Type', mimeForExt(ext))
  res.setHeader('Cache-Control', 'public, max-age=31536000, immutable')
  res.end(data)
}

function guessExt(contentType) {
  switch (contentType) {
    case 'image/png':
      return '.png'
    case 'image/jpeg':
      return '.jpg'
    case 'image/gif':
      return '.gif'
    case 'image/webp':
      return '.webp'
    case 'image/svg+xml':
      return '.svg'
    case 'application/pdf':
      return '.pdf'
    case 'video/mp4':
      return '.mp4'
    case 'video/webm':
      return '.webm'
    default:
      return ''
  }
}

function mimeForExt(ext) {
  switch (ext) {
    case '.png':
      return 'image/png'
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg'
    case '.gif':
      return 'image/gif'
    case '.webp':
      return 'image/webp'
    case '.svg':
      return 'image/svg+xml'
    case '.pdf':
      return 'application/pdf'
    case '.mp4':
      return 'video/mp4'
    case '.webm':
      return 'video/webm'
    default:
      return 'application/octet-stream'
  }
}

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
}

function sendJson(res, status, payload) {
  res.statusCode = status
  res.setHeader('Content-Type', 'application/json')
  cors(res)
  res.end(JSON.stringify(payload))
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    req.on('data', (chunk) => chunks.push(chunk))
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8')
        resolve(raw ? JSON.parse(raw) : {})
      } catch (error) {
        reject(error)
      }
    })
    req.on('error', reject)
  })
}
