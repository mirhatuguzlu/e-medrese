import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  base: '/e-medrese/',
  plugins: [react()],
  // CHANGELOG.md is read from the app repo root
  server: { fs: { allow: ['..'] } },
})
