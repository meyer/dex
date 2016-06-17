/* global chrome */

// Modules
import React from 'react'
import {Block, Flex, Inline} from 'jsxstyle'
import xhr from 'xhr'

// Components
import Switch from './Switch'
import Badge from './Badge'

// Utils
import getValidHostname from '../../lib/getValidHostname'

// Styles
import '../style.css'

import {dex} from '../../../package.json'
import {flatten, union} from 'lodash'
const dexURL = `https://${dex.host}:${dex.port}`

const Popover = React.createClass({
  getInitialState() {
    return {
      loading: true,
      xhrError: null,
      hostname: null,
      data: null,
    }
  },

  getHostnameFromHash() {
    if (window.location.hash.length === 0) {
      window.location.hash = 'test.dex.meyer.fm'
    }
    const hostname = getValidHostname('http://' + window.location.hash.slice(1))
    console.info('Setting hostname to', hostname)
    this.setState({hostname})
  },

  setHostname() {
    // Chrome extension
    if (
      typeof window !== 'undefined' &&
      typeof window.chrome === 'object' &&
      typeof window.chrome.tabs === 'object' &&
      window.chrome.tabs.query
    ) {
      window.chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
        const hostname = getValidHostname(tabs[0].url)
        this.setState({hostname})
      }.bind(this))

    // Demotron
    } else {
      this.getHostnameFromHash()
      window.addEventListener('hashchange', () => this.getHostnameFromHash())
    }
  },

  updateLastModifiedDateForHostname(hostname) {
    if (
      typeof window === 'undefined' ||
      typeof window.chrome !== 'object' ||
      typeof window.chrome.tabs !== 'object' ||
      !window.chrome.tabs.query
    ) {
      console.error('Cannot update hostname cachebuster: window.chrome.tabs.query is unavailable')
      return
    }

    const opts = {}
    opts[`lastUpdated-${hostname}`] = true

    chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
      chrome.tabs.sendMessage(tabs[0].id, opts, function(response) {
        if (response) {
          console.info('Response:', response)
        } else {
          console.info('Pinged current tab')
        }
      })
    })
  },

  componentWillMount() {
    if (typeof window !== 'undefined') {
      this.setHostname()
      this.fetchData()
    }
  },

  fetchData() {
    this.setState({xhrError: false, loading: true})

    xhr.get(`${dexURL}/${Date.now()}/config.json`, {json: true}, function (xhrError, resp, data) {
      if (xhrError) {
        console.error(xhrError)
      }

      this.setState({data, xhrError, loading: false})
    }.bind(this))
  },

  toggleModuleForHostname(moduleName, hostname) {
    if (this.state.loading) {
      console.warn('XHR already in progress')
      return
    }

    console.info('moduleName:', moduleName)
    this.setState({xhrError: false, loading: true})

    xhr.get(`${dexURL}/${Date.now()}/config.json?toggle=${moduleName}&hostname=${hostname}`, {json: true}, function (xhrError, resp, data) {
      if (xhrError) {
        console.error(xhrError)
        this.setState({xhrError, loading: false})
        return
      }

      if (resp.statusCode === 200) {
        if (typeof data === 'object') {
          this.setState({
            data: {
              ...this.state.data,
              enabled: data,
            },
            xhrError: false,
            loading: false,
          })
          this.updateLastModifiedDateForHostname(hostname)
        } else {
          this.setState({xhrError: false, loading: false})
          console.error(data.message)
        }
      }
    }.bind(this))
  },

  buildChildrenForHostname(hostname) {
    if (!this.state.data) {
      console.info(`No data for "${hostname}"`)
      return null
    }

    const {available, enabled} = this.state.data
    const children = []
    let domains = [hostname]

    const refreshButton = (
      <button
        style={{alignSelf: 'flex-end'}}
        onClick={() => this.updateLastModifiedDateForHostname(hostname)}>
        Refresh
      </button>
    )

    if (hostname != 'global') {
      // split sub.domain.com into [sub.domain.com, domain.com, com]
      domains = [].concat(hostname.split('.').map((e,i,r) => r.slice(i).join('.')), 'utilities')
    }

    const availableMods = flatten(domains.map((m) => available[m]).filter((f) => f))
    const enabledMods = enabled[hostname] || []

    const mods = union(enabledMods, availableMods).sort()

    mods.forEach(function(k, idx) {
      let badge, editable = true

      const [modCategory, modName] = k.split('/')
      if (modCategory === 'utilities') {
        badge = <Badge>Utility</Badge>
      } else {
        editable = !!~availableMods.indexOf(k)
        if (modCategory != hostname) {
          badge = <Badge>{modCategory}</Badge>
        }
      }

      // TODO: fix jsxtyle bug with `display` not being set
      children.push(
        <Flex
          component="li"
          display="flex"
          alignItems="center"
          key={`${hostname}-${k}-${idx}`}
          position="relative"
          fontSize={12}
          lineHeight="14px"
          backgroundColor="#FFF"
          marginTop={1}
          marginBottom={1}
          padding="6px 8px">
          {badge}
          <Block
            padding="1px 0"
            flexGrow={1}
            flexShrink={1}>
            {modName}
          </Block>
          <Block
            flexGrow={0}
            flexShrink={0}>
            <Switch
              marginLeft={7}
              onClick={() => editable && this.toggleModuleForHostname(k, hostname)}
              enabled={enabled[hostname] && !!~enabled[hostname].indexOf(k)}
              editable={editable}
            />
          </Block>
        </Flex>
      )
    }.bind(this))

    // TODO: Make this not suck
    if (children.length === 0) {
      return (
        <Flex padding={20}>
          <span>No modules exist for <strong>{hostname}</strong>.</span>
          {refreshButton}
        </Flex>
      )
    }

    return (
      <Block>
        <Flex
          alignItems="center"
          component="h1"
          padding="4px 8px"
          textTransform="uppercase"
          fontSize={11}
          lineHeight="12px"
          letterSpacing={1}>
          <Inline
            flexGrow={1}>{hostname}</Inline>
          {refreshButton}
        </Flex>
        <Block
          component="ul"
          backgroundColor="rgba(0,0,0,0.04)"
          overflow="hidden">
          {children}
        </Block>
      </Block>
    )
  },

  render(){
    if (this.state.xhrError) {
      return (
        <Block whiteSpace="nowrap" padding={15}>XHR Error broh</Block>
      )
    }

    if (this.state.loading && !this.state.data) {
      return (
        <Block whiteSpace="nowrap" padding={15}>Loading{'\u2026'}</Block>
      )
    }

    if (!this.state.hostname) {
      return (
        <Block whiteSpace="nowrap" padding={15}>Dex is disabled for this domain</Block>
      )
    }

    return (
      <Block
        width="100%"
        padding="4px 0">
        <Block marginBottom={8}>{this.buildChildrenForHostname(this.state.hostname)}</Block>
        <Block>{this.buildChildrenForHostname('global')}</Block>
      </Block>
    )
  },
})

export default Popover
