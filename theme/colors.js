const {
  blue,
  blueDark,
  green,
  greenDark,
  yellow,
  yellowDark,
  slate,
  slateDark,
  red,
  redDark,
  violet,
  violetDark,
} = require('@radix-ui/colors');

export const colors = {
  // Actualizar woot a paleta violeta (Yampi inspired)
  woot: {
    25: '#fefcff', // iris-1 equivalent
    50: '#fbf8ff', // iris-2 equivalent  
    75: '#f5eeff', // iris-3 equivalent
    100: '#ede0ff', // iris-4 equivalent
    200: '#e2ceff', // iris-5 equivalent
    300: '#d4b9ff', // iris-6 equivalent
    400: '#c4a1fc', // iris-7 equivalent
    500: '#b184f7', // iris-8 equivalent
    600: '#8b55f6', // iris-9 equivalent (primary)
    700: '#7c46e9', // iris-10 equivalent
    800: '#6d3bdb', // iris-11 equivalent
    900: '#341e6d', // iris-12 equivalent
  },
  
  // Mantener green pero más vibrante (teal-inspired)
  green: {
    50: '#fbfefe',
    100: '#f4fcfb',
    200: '#e2f9f6',
    300: '#cff4ef',
    400: '#baeee6',
    500: '#a5e3db',
    600: '#86d4cd',
    700: '#5ec0b8',
    800: '#2db3a8',
    900: '#134d49',
  },
  
  // Actualizar yellow/amber
  yellow: {
    50: yellow.yellow2,
    100: yellow.yellow3,
    200: yellow.yellow5,
    300: yellowDark.yellow10,
    400: yellowDark.yellow9,
    500: yellowDark.yellow11,
    600: yellow.yellow8,
    700: yellowDark.yellow7,
    800: yellowDark.yellow2,
    900: yellowDark.yellow1,
  },
  
  // Actualizar slate con tinte violeta
  slate: {
    25: '#fdfdff',
    50: '#fafafe',
    75: '#f3f3f9',
    100: '#ebebf2',
    200: '#e3e3ec',
    300: '#dbdbe6',
    400: '#cfcfdc',
    500: '#bcbccd',
    600: '#8e8ea2',
    700: '#838398',
    800: '#636373',
    900: '#1f1f28',
  },
  
  // Mantener black similar
  black: {
    50: '#fdfdfd',
    100: '#f0f0f0',
    200: '#e3e3ec',
    300: '#ebebf2',
    400: '#bcbccd',
    500: '#8e8ea2',
    600: '#838398',
    700: '#636373',
    800: '#4a4a5a',
    900: '#1f1f28',
  },
  
  // Actualizar red a magenta vibrante (ruby-inspired)
  red: {
    50: '#fffcfe',
    100: '#fff7fb',
    200: '#ffedf6',
    300: '#ffe0f0',
    400: '#ffd1e9',
    500: '#fcc0e0',
    600: '#f7acd4',
    700: '#f193c5',
    800: '#ec4899', // magenta vibrante
    900: '#5f1840',
  },
  
  // Mantener violet pero actualizar tonos
  violet: {
    50: violet.violet1,
    100: violetDark.violet12,
    200: violet.violet6,
    300: violet.violet8,
    400: violet.violet11,
    500: '#8b55f6', // violeta primario Yampi
    600: violetDark.violet8,
    700: violetDark.violet7,
    800: violetDark.violet6,
    900: violet.violet12,
  },

  // next design system color - mantener estructura
  n: {
    slate: {
      1: 'rgb(var(--slate-1) / <alpha-value>)',
      2: 'rgb(var(--slate-2) / <alpha-value>)',
      3: 'rgb(var(--slate-3) / <alpha-value>)',
      4: 'rgb(var(--slate-4) / <alpha-value>)',
      5: 'rgb(var(--slate-5) / <alpha-value>)',
      6: 'rgb(var(--slate-6) / <alpha-value>)',
      7: 'rgb(var(--slate-7) / <alpha-value>)',
      8: 'rgb(var(--slate-8) / <alpha-value>)',
      9: 'rgb(var(--slate-9) / <alpha-value>)',
      10: 'rgb(var(--slate-10) / <alpha-value>)',
      11: 'rgb(var(--slate-11) / <alpha-value>)',
      12: 'rgb(var(--slate-12) / <alpha-value>)',
    },

    iris: {
      1: 'rgb(var(--iris-1) / <alpha-value>)',
      2: 'rgb(var(--iris-2) / <alpha-value>)',
      3: 'rgb(var(--iris-3) / <alpha-value>)',
      4: 'rgb(var(--iris-4) / <alpha-value>)',
      5: 'rgb(var(--iris-5) / <alpha-value>)',
      6: 'rgb(var(--iris-6) / <alpha-value>)',
      7: 'rgb(var(--iris-7) / <alpha-value>)',
      8: 'rgb(var(--iris-8) / <alpha-value>)',
      9: 'rgb(var(--iris-9) / <alpha-value>)',
      10: 'rgb(var(--iris-10) / <alpha-value>)',
      11: 'rgb(var(--iris-11) / <alpha-value>)',
      12: 'rgb(var(--iris-12) / <alpha-value>)',
    },

    blue: {
      1: 'rgb(var(--blue-1) / <alpha-value>)',
      2: 'rgb(var(--blue-2) / <alpha-value>)',
      3: 'rgb(var(--blue-3) / <alpha-value>)',
      4: 'rgb(var(--blue-4) / <alpha-value>)',
      5: 'rgb(var(--blue-5) / <alpha-value>)',
      6: 'rgb(var(--blue-6) / <alpha-value>)',
      7: 'rgb(var(--blue-7) / <alpha-value>)',
      8: 'rgb(var(--blue-8) / <alpha-value>)',
      9: 'rgb(var(--blue-9) / <alpha-value>)',
      10: 'rgb(var(--blue-10) / <alpha-value>)',
      11: 'rgb(var(--blue-11) / <alpha-value>)',
      12: 'rgb(var(--blue-12) / <alpha-value>)',
    },

    ruby: {
      1: 'rgb(var(--ruby-1) / <alpha-value>)',
      2: 'rgb(var(--ruby-2) / <alpha-value>)',
      3: 'rgb(var(--ruby-3) / <alpha-value>)',
      4: 'rgb(var(--ruby-4) / <alpha-value>)',
      5: 'rgb(var(--ruby-5) / <alpha-value>)',
      6: 'rgb(var(--ruby-6) / <alpha-value>)',
      7: 'rgb(var(--ruby-7) / <alpha-value>)',
      8: 'rgb(var(--ruby-8) / <alpha-value>)',
      9: 'rgb(var(--ruby-9) / <alpha-value>)',
      10: 'rgb(var(--ruby-10) / <alpha-value>)',
      11: 'rgb(var(--ruby-11) / <alpha-value>)',
      12: 'rgb(var(--ruby-12) / <alpha-value>)',
    },

    amber: {
      1: 'rgb(var(--amber-1) / <alpha-value>)',
      2: 'rgb(var(--amber-2) / <alpha-value>)',
      3: 'rgb(var(--amber-3) / <alpha-value>)',
      4: 'rgb(var(--amber-4) / <alpha-value>)',
      5: 'rgb(var(--amber-5) / <alpha-value>)',
      6: 'rgb(var(--amber-6) / <alpha-value>)',
      7: 'rgb(var(--amber-7) / <alpha-value>)',
      8: 'rgb(var(--amber-8) / <alpha-value>)',
      9: 'rgb(var(--amber-9) / <alpha-value>)',
      10: 'rgb(var(--amber-10) / <alpha-value>)',
      11: 'rgb(var(--amber-11) / <alpha-value>)',
      12: 'rgb(var(--amber-12) / <alpha-value>)',
    },

    teal: {
      1: 'rgb(var(--teal-1) / <alpha-value>)',
      2: 'rgb(var(--teal-2) / <alpha-value>)',
      3: 'rgb(var(--teal-3) / <alpha-value>)',
      4: 'rgb(var(--teal-4) / <alpha-value>)',
      5: 'rgb(var(--teal-5) / <alpha-value>)',
      6: 'rgb(var(--teal-6) / <alpha-value>)',
      7: 'rgb(var(--teal-7) / <alpha-value>)',
      8: 'rgb(var(--teal-8) / <alpha-value>)',
      9: 'rgb(var(--teal-9) / <alpha-value>)',
      10: 'rgb(var(--teal-10) / <alpha-value>)',
      11: 'rgb(var(--teal-11) / <alpha-value>)',
      12: 'rgb(var(--teal-12) / <alpha-value>)',
    },

    gray: {
      1: 'rgb(var(--gray-1) / <alpha-value>)',
      2: 'rgb(var(--gray-2) / <alpha-value>)',
      3: 'rgb(var(--gray-3) / <alpha-value>)',
      4: 'rgb(var(--gray-4) / <alpha-value>)',
      5: 'rgb(var(--gray-5) / <alpha-value>)',
      6: 'rgb(var(--gray-6) / <alpha-value>)',
      7: 'rgb(var(--gray-7) / <alpha-value>)',
      8: 'rgb(var(--gray-8) / <alpha-value>)',
      9: 'rgb(var(--gray-9) / <alpha-value>)',
      10: 'rgb(var(--gray-10) / <alpha-value>)',
      11: 'rgb(var(--gray-11) / <alpha-value>)',
      12: 'rgb(var(--gray-12) / <alpha-value>)',
    },

    black: '#000000',
    brand: '#8B55F6', // Nuevo color brand violeta Yampi
    background: 'rgb(var(--background-color) / <alpha-value>)',
    solid: {
      1: 'rgb(var(--solid-1) / <alpha-value>)',
      2: 'rgb(var(--solid-2) / <alpha-value>)',
      3: 'rgb(var(--solid-3) / <alpha-value>)',
      active: 'rgb(var(--solid-active) / <alpha-value>)',
      amber: 'rgb(var(--solid-amber) / <alpha-value>)',
      blue: 'rgb(var(--solid-blue) / <alpha-value>)',
      iris: 'rgb(var(--solid-iris) / <alpha-value>)',
    },
    alpha: {
      1: 'rgba(var(--alpha-1))',
      2: 'rgba(var(--alpha-2))',
      3: 'rgba(var(--alpha-3))',
      black1: 'rgba(var(--black-alpha-1))',
      black2: 'rgba(var(--black-alpha-2))',
      white: 'rgba(var(--white-alpha))',
    },
    weak: 'rgb(var(--border-weak) / <alpha-value>)',
    container: 'rgba(var(--border-container))',
    strong: 'rgb(var(--border-strong) / <alpha-value>)',
    'blue-border': 'rgba(var(--border-blue))',
    'blue-text': 'rgba(var(--text-blue))',
  },
};
