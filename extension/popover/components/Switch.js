import React from 'react'
import {Block} from 'jsxstyle'

export default function Switch(props) {
  const switchSize = 12
  const switchTravel = 8
  const switchPadding = 1

  const switchBackgroundStyle = {
    backgroundColor: 'rgba(0,0,0,0.05)',
    backgroundImage: 'linear-gradient(to bottom, rgba(0,0,0,0.04) 40%, rgba(0,0,0,0))',
    boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.1)',
    height: switchSize + switchPadding * 2,
    width: switchSize + switchTravel + switchPadding * 2,
    borderRadius: switchSize,
    position: 'relative',
    cursor: 'pointer',
    transition: 'background-color 180ms ease-in-out 80ms',
    ...props,
  }

  if (props.enabled && props.editable) {
    switchBackgroundStyle.backgroundColor = 'rgb(130,220,90)'
  }

  if (!props.editable) {
    switchBackgroundStyle.backgroundColor = 'rgb(228, 90, 71)'
  }

  return (
    <div
      style={switchBackgroundStyle}
      onClick={props.onClick}>
      <Block
        height={switchSize}
        width={switchSize}
        borderRadius={switchSize}
        left={switchPadding}
        top={switchPadding}
        transition="transform 140ms ease-in-out"
        transform={props.enabled ? `translateX(${switchTravel}px)` : null}
        position="absolute"
        backgroundColor="#FFF"
        backgroundImage="linear-gradient(to bottom, rgba(0,0,0,0) 40%, rgba(0,0,0,0.05))"
        boxShadow="0 0 0 1px rgba(0,0,0,0.1)"
      />
    </div>
  )
}

Switch.propTypes = {
  enabled: React.PropTypes.bool,
  editable: React.PropTypes.bool,
  onClick: React.PropTypes.func,
}
