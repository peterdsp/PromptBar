/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./site/*.html'],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'SF Pro Text',
          'SF Pro Display',
          'Inter',
          'system-ui',
          'Segoe UI',
          'Helvetica',
          'Arial',
          'sans-serif',
        ],
        mono: ['SF Mono', 'ui-monospace', 'Menlo', 'Consolas', 'monospace'],
      },
      colors: {
        ink: {
          950: '#07070c',
          900: '#0b0b12',
          800: '#111119',
          700: '#171722',
          600: '#1f1f2d',
        },
        accent: {
          400: '#7dd3fc',
          500: '#38bdf8',
          600: '#0ea5e9',
        },
        mint: {
          400: '#5eead4',
          500: '#2dd4bf',
        },
        lilac: {
          400: '#c4b5fd',
          500: '#a78bfa',
        },
      },
      boxShadow: {
        glass:
          '0 1px 0 0 rgba(255,255,255,0.08) inset, 0 0 0 1px rgba(255,255,255,0.06), 0 30px 60px -20px rgba(0,0,0,0.7)',
        soft: '0 20px 60px -20px rgba(0,0,0,0.6)',
      },
    },
  },
  plugins: [],
};
