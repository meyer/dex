const webpack = require('webpack')

const NODE_ENV = process.env.NODE_ENV || 'production'

const webpackPlugins = [
  new webpack.DefinePlugin({
    'process.env.NODE_ENV': JSON.stringify(NODE_ENV),
  }),
]

if (NODE_ENV === 'production') {
  webpackPlugins.push(
    new webpack.optimize.UglifyJsPlugin({
      compress: {
        drop_console: true,
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
