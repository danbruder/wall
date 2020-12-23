const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  purge: [
     './src/**/*.elm',
   ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
}
