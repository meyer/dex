module.exports = {
  parserOptions: {
    sourceType: 'module',
    ecmaVersion: 6,
    ecmaFeatures: {
      jsx: true,
      experimentalObjectRestSpread: true,
    },
  },

  rules: {
    'indent': [2, 2],
    'quotes': [2, 'single'],
    'linebreak-style': [2, 'unix'],
    'semi': [2, 'always'],
    'strict': [2, 'global'],
    'comma-dangle': [2, 'always-multiline'],
    'no-console': 0,
    // 'space-before-function-paren': 2,
    'keyword-spacing': 2,
  },

  env: {
    es6: true,
    node: true,
    browser: true,
  },

  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
  ],

  plugins: [
    'react',
  ],

  globals: {},
};
