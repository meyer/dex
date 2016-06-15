import React from 'react'
import {Block} from 'jsxstyle'

export default function Switch(props) {
  const {
    switchSize,
    switchTravel,
    switchPadding,
    enabled,
    editable,
    onClick,
    ...styleProps,
  } = props

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
    ...styleProps,
  }

  if (enabled && editable) {
    switchBackgroundStyle.backgroundColor = 'rgb(130,220,90)'
  }

  if (!editable) {
    switchBackgroundStyle.backgroundColor = 'rgb(228, 90, 71)'
  }

  return (
    <div
      style={switchBackgroundStyle}
      onClick={onClick}>
      <Block
        height={switchSize}
        width={switchSize}
        borderRadius={switchSize}
        left={switchPadding}
        top={switchPadding}
        transition="transform 140ms ease-in-out"
        transform={enabled ? `translateX(${switchTravel}px)` : null}
        position="absolute"
        backgroundColor="#FFF"
        backgroundImage="linear-gradient(to bottom, rgba(0,0,0,0) 40%, rgba(0,0,0,0.05))"
        boxShadow="0 0 0 1px rgba(0,0,0,0.1)"
      />
    </div>
  )
}

Switch.propTypes = {
  switchSize: React.PropTypes.number.isRequired,
  switchTravel: React.PropTypes.number.isRequired,
  switchPadding: React.PropTypes.number.isRequired,
  enabled: React.PropTypes.bool,
  editable: React.PropTypes.bool,
  onClick: React.PropTypes.func,
}

Switch.defaultProps = {
  switchSize: 12,
  switchTravel: 8,
  switchPadding: 1,
}
