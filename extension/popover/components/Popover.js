/* global chrome */

// Modules
import React from 'react';
import {InlineBlock, Flex, Block} from 'jsxstyle';
import xhr from 'xhr';

// Components
import Switch from './Switch';

// Utils
import getValidHostname from '../../lib/getValidHostname';

// Styles
import '../style.css';

import {dexURL} from '../../package.json';

const Popover = React.createClass({
  getInitialState: () => ({
    loading: true,
    xhrError: null,
    hostname: null,
    data: null,
  }),

  getData: function() {
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

  updateLastModifiedDate: function(hostname) {
    const opts = {};
    opts[`lastUpdated-${hostname}`] = true;

    chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
      chrome.tabs.sendMessage(tabs[0].id, opts, function(response) {
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

    xhr.get(`${dexURL}/${hostname}.json`, {json: true}, function (xhrError, resp, data) {
      if (xhrError) {
        console.error(xhrError);
      }

      this.setState({data, xhrError, loading: false});
    }.bind(this));
  },

  toggleModuleForHostname: function(moduleName, hostname) {
    if (this.state.loading) {
      console.warn('XHR already in progress');
      return;
    }

    console.log('moduleName:', moduleName);

    this.setState({xhrError: false, loading: true});

    xhr.get(`${dexURL}/${hostname}.json?toggle=${moduleName}`, {json: true}, function (xhrError, resp, data) {
      if (xhrError) {
        console.error(xhrError);
        this.setState({xhrError, loading: false});
        return;
      }

      if (resp.statusCode === 200) {
        if (data.status === 'success') {
          const updatedData = this.state.data;
          updatedData[hostname][moduleName] = data.action === 'enabled';

          this.setState({data: updatedData, xhrError: false, loading: false});
          this.updateLastModifiedDate(hostname);
          console.log(data.message);
        } else {
          this.setState({xhrError: false, loading: false});
          console.error(data.message);
        }
      }
    }.bind(this));
  },

  buildChildrenForDomain: function(hostname) {
    if (!this.state.data) {
      console.log(`No data for "${hostname}"`);
      return null;
    }

    console.log('data:', this.state.data);

    if (!this.state.data[hostname]) {
      console.error(`Invalid hostname "${hostname}". Your options: ${Object.keys(this.state.data).join(', ')}`);
      return;
    }

    const available = Object.keys(this.state.data[hostname]);

    if (available.length === 0) {
      return (
        <Block
          padding={20}>
          No modules exist for <strong>{hostname}</strong>.
        </Block>
      );
    }

    const children = available.map(function(k, idx) {
      let badge, editable = true;

      const [modCategory, modName] = k.split('/');

      if (modCategory === 'utilities') {
        // alignSelf="flex-start" ??
        badge = (
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
            boxShadow="0 0 0 1px rgba(0,0,0,0.14)">
            Utility
          </InlineBlock>
        );
      } else {
        editable = modCategory === hostname;
      }

      return (
        <Flex
          alignItems="center"
          key={`${hostname}-${k}-${idx}`}
          component="li"
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
              onClick={() => this.toggleModuleForHostname(k, hostname)}
              enabled={this.state.data[hostname][k]}
              editable={editable}
            />
          </Block>
        </Flex>
      );
    }.bind(this));

    return (
      <Block>
        <Block
          component="h1"
          padding="4px 8px"
          textTransform="uppercase"
          fontSize={10.5}
          lineHeight="12px"
          letterSpacing={1}>
          {hostname}
        </Block>
        <Block
          component="ul"
          backgroundColor="rgba(0,0,0,0.04)"
          overflow="hidden">
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
      <Block
        width="100%"
        padding="4px 0">
        <Block marginBottom={8}>{this.buildChildrenForDomain(this.state.hostname)}</Block>
        <Block>{this.buildChildrenForDomain('global')}</Block>
      </Block>
    );
  },
});

export default Popover;
