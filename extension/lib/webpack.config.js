const webpack = require('webpack')

const webpackPlugins = [
  new webpack.DefinePlugin({
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
    'process.env.DEX_URL': JSON.stringify(process.env.DEX_URL),
  }),
]

if (process.env.NODE_ENV === 'production') {
  webpackPlugins.push(
    new webpack.optimize.UglifyJsPlugin({
      compress: {
        // drop_console: true,
      },
    }),
    new webpack.optimize.OccurenceOrderPlugin()
  )
}

const webpackConfig = {
  plugins: webpackPlugins,
  module: {
    loaders: [
      {
        test: /\.js$/,
        loader: require.resolve('babel-loader'),
        query: {
          presets: [
            require.resolve('babel-preset-es2015'),
          ],
          plugins: [
            require.resolve('babel-plugin-transform-object-rest-spread'),
          ],
        },
        // include: ...,
        // exclude: ...,
      },
      {
        test: /\.json$/,
        loader: require.resolve('json-loader'),
      },
    ],
  },
}

module.exports = webpackConfig
