import React from 'react'
import {InlineBlock} from 'jsxstyle'

export default function Badge(props) {
  return (
    <InlineBlock
      flexGrow={0}
      flexShrink={0}
      fontSize={8.8}
      height={12}
      lineHeight="12px"
      fontWeight={700}
      color="rgba(0,0,0,0.4)"
      textTransform="uppercase"
      padding="0 3px"
      marginRight={6}
      borderRadius={2}
      backgroundColor="#FFF"
      boxShadow="0 0 0 1px rgba(0,0,0,0.14)"
      {...props}
    />
  )
}
