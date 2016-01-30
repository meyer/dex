'use strict';

// Modules
const React = require('react');
const {InlineBlock, Flex, Block} = require('jsxstyle');
const xhr = require('xhr');

// Components
const Switch = require('./Switch');

// Utils
const {getValidHostname} = require('../utils');

// Styles
require('../assets/style.css');

const baseURL = 'https://localhost:3131/';

const Popover = React.createClass({
  getInitialState: () => ({
    url: null,
    hostname: null,
    site_available: null,
    site_enabled: null,
    global_available: null,
    global_enabled: null,
    metadata: {},
  }),

  componentDidMount: function() {
    // Safari extension
    if (
      window &&
      typeof window.safari === 'object' &&
      typeof window.safari.application === 'object'
    ) {
      this.getDataForURL(window.safari.application.activeBrowserWindow.activeTab.url);
    } else

    // Chrome extension
    if (
      window &&
      typeof window.chrome === 'object' &&
      typeof window.chrome.tabs === 'object' &&
      window.chrome.tabs.getSelected
    ) {
      window.chrome.tabs.getSelected(null, function(tab) {
        this.getDataForURL(tab.url);
      }.bind(this));

    // Demotron
    } else {
      // Testing this requires running Chrome with --disable-web-security
      this.getDataForURL('http://dribbble.com');
    }
  },

  getDataForURL: function(url) {
    const hostname = getValidHostname(url);

    if (!hostname) {
      console.error('Invalid URL:', url);
      return;
    }

    xhr.get(`${baseURL}${hostname}.json`, {json: true}, function (err, resp, data) {
      console.log('ERR:', err);
      console.log('RESP:', resp);

      if (err) {
        console.error(err);
        return;
      }

      if (resp.statusCode === 200) {
        this.setState({url, hostname, ...data});
      }
    }.bind(this));
  },

  toggleModuleForHostname: function(mod, hostname) {
    xhr.get(`${baseURL}${hostname}.json?toggle=${mod}`, {json: true}, function (err, resp, data) {
      console.log('ERR:', err);
      console.log('RESP:', resp);

      if (err) {
        console.error(err);
        return;
      }

      if (resp.statusCode === 200) {
        if (data.status === 'success') {
          const g = hostname === 'global' ? 'global_enabled' : 'site_enabled';
          const newState = {};

          if (data.action === 'enabled') {
            newState[g] = [].concat(this.state[g], mod);
          } else if (data.action === 'disabled') {
            newState[g] = this.state[g].filter((el) => el !== mod);
          }

          this.setState(newState);
          console.log(data.message);
        } else {
          console.error(data.message);
        }
      }
    }.bind(this));
  },

  buildChildrenFromArray: function(who) {
    let available, enabled, hostname;
    if (who === 'site') {
      hostname = this.state.hostname;
      available = this.state.site_available;
      enabled = this.state.site_enabled;
    } else if (who === 'global') {
      hostname = who;
      available = this.state.global_available;
      enabled = this.state.global_enabled;
    }

    if (!Array.isArray(available) || available.length === 0) {
      return (
        <Block
          padding={20}>
          No modules exist for <strong>{hostname}</strong>.
        </Block>
      );
    }

    const children = available.map(function(mod, idx, arr) {
      const md = this.state.metadata[mod];

      let badge;

      if (md['Category'] === 'utilities') {
        badge = (
          <InlineBlock
            fontSize={10}
            fontWeight={800}
            color="#FFF"
            textShadow="0 1px 1px rgba(0,0,0,0.2)"
            textTransform="uppercase"
            padding="1px 4px"
            marginRight={5}
            borderRadius={3}
            backgroundColor="rgba(0,0,0,0.15)"
            backgroundImage="linear-gradient(to bottom, rgba(0,0,0,0.15), rgba(0,0,0,0))"
            boxShadow="inset 0 0 0 1px rgba(0,0,0,0.1)">
            Utility
          </InlineBlock>
        );

        // alignSelf="flex-start" ??
        badge = (
          <InlineBlock
            flex={0}
            fontSize={10}
            height={15}
            fontWeight={800}
            color="rgba(0,0,0,0.3)"
            textTransform="uppercase"
            padding="0 3px"
            marginRight={5}
            borderRadius={2}
            backgroundColor="#FFF"
            boxShadow="0 0 0 1px rgba(0,0,0,0.1)">
            Utility
          </InlineBlock>
        );
      }

      return (
        <Flex
          alignItems="center"
          key={mod}
          component="li"
          position="relative"
          boxShadow="0 1px 0 rgba(0,0,0,0.07)"
          fontSize={12}
          lineHeight="14px"
          padding="6px 8px">
          {badge}
          <Block
            padding="1px 0"
            flex={1}>
            {md['Title']}
          </Block>
          <Block flex={0}>
            <Switch
              marginLeft={7}
              onClick={() => this.toggleModuleForHostname(mod, hostname)}
              enabled={~enabled.indexOf(mod)}
            />
          </Block>
        </Flex>
      );
    }.bind(this));

    return (
      <Block>
        <Block
          component="h1"
          padding="0 10px"
          textTransform="uppercase"
          fontSize={10}
          backgroundColor="rgba(0,0,0,0.1)"
          boxShadow="inset 0 -1px 0 rgba(0,0,0,0.07)"
          letterSpacing={1}>
          {hostname}
        </Block>
        <Block component="ul">
          {children}
        </Block>
      </Block>
    );
  },

  render: function(){
    return (
      <Block>
        <Block>{this.buildChildrenFromArray('site')}</Block>
        <Block>{this.buildChildrenFromArray('global')}</Block>
      </Block>
    );
  },
});

module.exports = Popover;
