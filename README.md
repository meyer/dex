# Meet Dex.

**Dex** is tool that allows you to modify websites with some CSS and JavaScript.

It’s a two-part system:

1. A node-powered **daemon** that serves the CSS and JS files.
2. A **browser extension** for Chrome and Safari that loads those files into your browser.

This is the source code for the browser extension.

## Getting Started: Installation

1. The Dex daemon can be installed through **NPM**. NPM stands for Node Package Manager, and it’s a key part of **node**. You can download and install **node** over at the [official NodeJS website][install node].

	Once node is installed, you’ll have access to NPM. Install dex:

		npm install -g dex
		dex wiz

	That last line will run a wizard that’ll ask you a few questions. The default settings are in brackets. If you hit Enter, that default will be used.

	Once the dex wizard has done its thing, the `dex` daemon should be up and running. The daemon will automatically start when your computer boots up.

2. Install the Dex browser extension:
	* **Safari**: [Download the Safari extension][safariextz] and double-click
		it to install.
	* **Chrome**: Install the extension at the [official extension page][crx].

3. Go to [localhost:3131][dexurl]. Your browser will complain about the self-signed SSL certificate. Mark the certificate as “trusted”. There’s an “Always Trust” option in there somewhere. Check the box.


## Modules: The core of Dex

Every time you visit a URL, the Dex browser extension loads one special CSS file and one special JS file for that specific domain. These two files are specifically built based on *modules* that you have enabled in the Dex extension popover.

What is a *module*? It’s a sensibly-named folder with some CSS and/or JS files that, when included on a webpage, accomplish a single task. Modules live in subfolders inside a folder of your choosing. By default, that folder is called `Dex`, and it’s in your home directory (`/Users/your-username/`, also known as `~`). Modules can be placed in three different types of subfolders, depending on what the scope of the module should be. Here’s the breakdown:

1. If you want to modify *one particular site*, you’ll want to place the module in a *site-specific folder*. Site-specific folders are URL-named folders (`~/.dex/github.com/`, `~/.dex/google.com/`, etc.). Enabled site-specific modules are only loaded for the exact matching URL. Subdomains of URLs are treated as separate URLs and can be configured independently of the parent URL, but they have access to all the parent URL’s modules. This is especially useful when dealing with beta subdomains.

2. If you want to modify *every site you visit*, you’ll want to put the module inside a folder called `~/.dex/global/`. Enabled global modules are loaded on every page load of every webpage you visit.

3. If you want to modify any particular site, but *not all sites*, you’ll want to put your module folder inside a folder called `~/.dex/utilities/`. Utility modules show up as regular site-specific modules in the Dex popover, but enabling a utility module will only enable it for the specific domain that you’ve browsed to.


## Writing your first module

1. First, you need to decide what you want your module to do. Create a folder with a sensible and identifiable name related to the module’s actions. Do you want to make a website’s background red? Make a folder called `Change body background to red`.
2. Put CSS and JS files corresponding to the particular module’s actions in the folder you just created.
1. Next, you need to decide what the scope of your module should be. Consult the previous section of this README to determine scope, then place the folder you created into a corresponding parent folder.
3. Visit the URL you want to modify, open the Dex popover menu, and click `Change body background to red` to enable the module.
4. Refresh the web page. The module CSS and JS should load right away.


### Pro Tips

Files are loaded alphabetically. Prefix a module name with underscores or spaces to bump it up the module list.

If you’re unsure how everything’s loading, you can go to `https://localhost:3131/example.com.js` or `https://localhost:3131/example.com.css` to see the file that the Dex browser extension is loading.


### File Load Order
Dex loads files in the following order:

1. `~/.dex/global/*.js`
2. `~/.dex/global/*/*.{css,js}`
3. `~/.dex/example.com/*.js`
4. `~/.dex/example.com/*/*.{css,js}`

Files are bunched into one file per file type and served over `https`.




# Talk to me.
Got a problem or a suggestion? Here’s how to get ahold of me, in preferred order:

1. [Start an issue][issues].
2. Send me an email: [email][]
999. Bug me on Twitter: [@meyer][]

[install node]: http://nodejs.org/download/
[crx]: https://chrome.google.com/webstore/detail/dex/djkimknbcjbgnocjbbmliklifoflmfah
[safariextz]: https://github.com/meyer/dex/raw/master/extensions/dex-1.0.1.safariextz
[dexurl]: https://localhost:3131
[@meyer]: http://twitter.com/meyer
[email]: mailto:github.com+dex@meyer.fm
[issues]: https://github.com/meyer/dex/issues