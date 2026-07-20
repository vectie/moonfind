import { defineConfig } from 'vite'

export default defineConfig({
  appType: 'spa',
  server: { port: 4187 },
  build: { outDir: 'dist', emptyOutDir: true },
})
