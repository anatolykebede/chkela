import path from 'node:path'
import { fileURLToPath } from 'node:url'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { giftCodesApiPlugin } from '../shared/giftCodes/vitePlugin.mjs'
import { referralsApiPlugin } from '../shared/referrals/vitePlugin.mjs'

const rootDir = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [
    react(),
    giftCodesApiPlugin({
      giftCodesFile: path.resolve(rootDir, '../shared/giftCodes/data.json'),
      studentsFile: path.resolve(rootDir, '../shared/students/data.json'),
    }),
    referralsApiPlugin({
      referralsFile: path.resolve(rootDir, '../shared/referrals/data.json'),
    }),
  ],
  server: {
    port: 5174,
    fs: { allow: ['..'] },
  },
})
