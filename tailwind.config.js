/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'decent-blue': '#0066cc',
        'decent-dark': '#1a1a1a',
      },
    },
  },
  plugins: [],
}
