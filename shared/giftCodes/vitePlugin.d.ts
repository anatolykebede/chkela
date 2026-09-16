declare module '*vitePlugin.mjs' {
  import type { Plugin } from 'vite'

  export function giftCodesApiPlugin(options: {
    giftCodesFile: string
    studentsFile: string
  }): Plugin
}
