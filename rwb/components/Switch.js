'use strict';

const React = require('react');
const {Block} = require('jsxstyle');

const Switch = React.createClass({
  getDefaultProps: () => ({
    enabled: false,
  }),

  getInitialState: () => ({
    enabled: false,
  }),

  componentWillMount: function() {
    this.setState({
      enabled: this.props.enabled,
    });
  },

  render: function() {
    const {enabled, onClick, ...props} = this.props;

    const switchHeight = 10;
    const switchWidth = 20;
    const switchPadding = 1;

    const switchBackgroundStyle = {
      backgroundColor: '#DDD',
      backgroundImage: 'linear-gradient(to bottom, rgba(0,0,0,0.04) 40%, rgba(0,0,0,0))',
      boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.1)',
      height: switchHeight + switchPadding * 2,
      width: switchWidth,
      borderRadius: switchHeight,
      position: 'relative',
      cursor: 'pointer',
      transition: 'background-color 140ms ease-in-out 80ms',
      ...props,
    };

    if (enabled) {
      switchBackgroundStyle.backgroundColor = 'rgb(130,220,90)';
    }

    return (
      <div
        style={switchBackgroundStyle}
        onClick={onClick}>
        <Block
          height={switchHeight}
          width={switchHeight}
          borderRadius={switchHeight}
          left={switchPadding}
          top={switchPadding}
          transition="transform 140ms ease-in-out"
          transform={enabled ? `translateX(${switchWidth - switchHeight - switchPadding * 2}px)` : null}
          position="absolute"
          backgroundColor="#FFF"
          backgroundImage="linear-gradient(to bottom, rgba(0,0,0,0) 40%, rgba(0,0,0,0.05))"
          boxShadow="0 0 0 1px rgba(0,0,0,0.1)"
        />
      </div>
    );
  },
});

module.exports = Switch;
