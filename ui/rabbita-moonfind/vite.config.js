import { defineConfig } from 'vite'

export default defineConfig({
  appType: 'spa',
  base: './',
  server: { port: 4187 },
  build: { outDir: 'dist', emptyOutDir: true },
})
