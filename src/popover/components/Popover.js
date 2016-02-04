/* global chrome */
'use strict';

// Modules
const React = require('react');
const {InlineBlock, Flex, Block} = require('jsxstyle');
const xhr = require('xhr');

// Components
const Switch = require('./Switch');

// Utils
const {getValidHostname} = require('../../_utils');

// Styles
require('../style.css');

const {dexURL} = require('../../../package.json');

const Popover = React.createClass({
  getInitialState: () => ({
    loading: true,
    xhrError: null,
    hostname: null,
    data: null,
  }),

  getData: function() {
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
      window.chrome.tabs.query
    ) {
      chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
        this.getDataForURL(tabs[0].url);
      }.bind(this));
    // Demotron
    } else {
      // Testing this requires running Chrome with --disable-web-security
      this.getDataForURL('http://dribbble.com');
    }
  },

  updateLastModifiedDate: function() {
    chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
      chrome.tabs.sendMessage(tabs[0].id, {
        updateLastModified: true,
      }, function(response) {
        if (response) {
          console.log('Response:', response);
        } else {
          console.log('Pinged current tab');
        }
      });
    });
  },

  componentDidMount: function() {
    this.getData();
  },

  getDataForURL: function(url) {
    const hostname = getValidHostname(url);

    if (!hostname) {
      console.error('Invalid URL:', url);
      this.setState({loading: false});
      return;
    }

    this.setState({hostname, xhrError: false, loading: true});

    xhr.get(`${dexURL}${hostname}.json`, {json: true}, function (xhrError, resp, data) {
      if (xhrError) {
        console.error(xhrError);
      }

      this.setState({data, xhrError, loading: false});
    }.bind(this));
  },

  toggleModuleForHostname: function(mod, hostname) {
    if (this.state.loading) {
      console.warn('XHR already in progress');
      return;
    }

    this.setState({xhrError: false, loading: true});

    xhr.get(`${dexURL}${hostname}.json?toggle=${mod}`, {json: true}, function (xhrError, resp, data) {
      if (xhrError) {
        console.error(xhrError);
        this.setState({xhrError, loading: false});
        return;
      }

      if (resp.statusCode === 200) {
        if (data.status === 'success') {
          const data_key = (hostname === 'global') ? 'global_enabled' : 'site_enabled';
          const updatedData = this.state.data;

          if (data.action === 'enabled') {
            updatedData[data_key] = [].concat(this.state.data[data_key], mod);
          } else if (data.action === 'disabled') {
            updatedData[data_key] = this.state.data[data_key].filter((el) => el !== mod);
          }

          this.setState({data: updatedData, xhrError: false, loading: false});
          this.updateLastModifiedDate();
          console.log(data.message);
        } else {
          this.setState({data: null, xhrError: false, loading: false});
          console.error(data.message);
        }
      }
    }.bind(this));
  },

  buildChildrenFromArray: function(who) {
    if (!this.state.data) {
      return null;
    }

    let available, enabled, hostname;
    if (who === 'site') {
      hostname = this.state.hostname;
      available = this.state.data.site_available;
      enabled = this.state.data.site_enabled;
    } else if (who === 'global') {
      hostname = who;
      available = this.state.data.global_available;
      enabled = this.state.data.global_enabled;
    }

    if (!Array.isArray(available) || available.length === 0) {
      return (
        <Block
          padding={20}>
          No modules exist for <strong>{hostname}</strong>.
        </Block>
      );
    }

    const children = available.map(function(mod) {
      const md = this.state.data.metadata[mod];

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
          fontSize={10.5}
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
    if (this.state.xhrError) {
      return (
        <Block whiteSpace="nowrap" padding={15}>XHR Error broh</Block>
      );
    }

    if (this.state.loading && !this.state.data) {
      return (
        <Block whiteSpace="nowrap" padding={15}>Loading{'\u2026'}</Block>
      );
    }

    if (!this.state.hostname) {
      return (
        <Block whiteSpace="nowrap" padding={15}>Dex is disabled for this domain</Block>
      );
    }

    return (
      <Block minWidth={300}>
        <Block>{this.buildChildrenFromArray('site')}</Block>
        <Block>{this.buildChildrenFromArray('global')}</Block>
      </Block>
    );
  },
});

module.exports = Popover;
