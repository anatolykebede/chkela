import path from 'node:path'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { giftCodesApiPlugin } from '../shared/giftCodes/vitePlugin.mjs'
import { contentApiPlugin } from '../shared/content/vitePlugin.mjs'
import { referralsApiPlugin } from '../shared/referrals/vitePlugin.mjs'
import { feedbackApiPlugin } from '../shared/feedback/vitePlugin.mjs'
import { appConfigApiPlugin } from '../shared/appConfig/vitePlugin.mjs'
import { pathApiPlugin } from '../shared/path/vitePlugin.mjs'

const rootDir = path.dirname(fileURLToPath(import.meta.url))

/** Load server/.env into process.env for Vite CMS admin JWT checks. */
function loadServerEnv() {
  const envPath = path.resolve(rootDir, '../server/.env')
  if (!fs.existsSync(envPath)) return
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const eq = trimmed.indexOf('=')
    if (eq <= 0) continue
    const key = trimmed.slice(0, eq).trim()
    let val = trimmed.slice(eq + 1).trim()
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1)
    }
    if (!process.env[key]) process.env[key] = val
  }
}

loadServerEnv()

export default defineConfig({
  plugins: [
    react(),
    giftCodesApiPlugin({
      giftCodesFile: path.resolve(rootDir, '../shared/giftCodes/data.json'),
      studentsFile: path.resolve(rootDir, '../shared/students/data.json'),
    }),
    contentApiPlugin({
      contentFile: path.resolve(rootDir, '../shared/content/data.json'),
      assetsContentFile: path.resolve(rootDir, '../assets/content/data.json'),
      assetsFiguresDir: path.resolve(rootDir, '../assets/content/figures'),
    }),
    pathApiPlugin({
      pathFile: path.resolve(rootDir, '../shared/path/data.json'),
      assetsPathFile: path.resolve(rootDir, '../assets/path/data.json'),
      progressFile: path.resolve(rootDir, '../shared/path/progress.json'),
    }),
    referralsApiPlugin({
      referralsFile: path.resolve(rootDir, '../shared/referrals/data.json'),
    }),
    feedbackApiPlugin({
      feedbackFile: path.resolve(rootDir, '../shared/feedback/data.json'),
    }),
    appConfigApiPlugin({
      appConfigFile: path.resolve(rootDir, '../shared/appConfig/data.json'),
    }),
  ],
  server: {
    host: true,
    port: 5173,
    fs: { allow: ['..'] },
    proxy: {
      '/api/admin': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/auth': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/users': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/chat': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/friends': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/notifications': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/subscriptions': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/payments': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/leaderboard': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
      '/api/ai': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
      },
    },
  },
})
