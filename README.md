# Meet Dex.

Quite simply, Dex is tool that allows you to load custom JS and CSS on a per-site basis.

It’s a two-part system—a tiny li’l webrick server that runs on port 3131 and chucks JS and CSS files from `~/.dex`, and a browser extension that loads those files (and jQuery) into Your Browser of Choice (assuming that you chose Chrome or Safari).

## How do I get it?

A fair question, but not one we’ll cover today. If you’d like to install Dex, though, here’s the deal. Three steps:

1. Clone the `dex` repository to somewhere sensible and install the daemon.

		git clone --recursive https://github.com/meyer/dex.git
		cd dex
		rake

	That’ll install the `dex` server to `/usr/local/bin` and set it to automatically start when your computer boots up.

2. Install the browser extension in Your Cool Browser.
	* **Safari**: [Download the Safari extension][safariextz] and double-click
		it to install.
	* **Chrome**: Install the extension at the [official extension page][crx].

3. Go to [localhost:3131][dexurl]. Your browser will complain about the self-signed SSL certificate. Mark the certificate as “trusted”. There’s an “Always Trust” option in there somewhere. Check the box.

## What now?
Dex should be up and running all smooth-like with a few default modules loaded. You can see and change modules per-site at `https://localhost:3131/SITEURL.com.html`. Click the module name to enable or disable. It’s still a bit janky, but don’t worry—I’ll be making that a whole lot sexier as soon as I have the time.

## Write Yourself a Module
1. Do you want to modify *one particular site* (`example.com`)?

	1. Create a folder in `~/.dex/` named `example.com`. In your newly created folder, create a folder named something descriptive, like `change background to red`.
	2. Put CSS and JS files corresponding to the particular module in `change background to red`.

	Files are loaded alphabetically, so if you’ve got one file that relies on another, prefix the filename with an underscore or something. Or call it something like “aaaa load first.js” Nokia style. Whatever.

	If you’re unsure how everything’s loading, you can go to `https://localhost:3131/example.com.js` or `https://localhost:3131/example.com.css` to see the file that the extension is loading.

2. Do you want to modify *every site you visit*?

	1. Create a folder in `~/.dex/` named `global` if it doesn’t exist already.
	2. Follow step 2 above. BAM!

### File Load Order
Dex loads files in the following order:

1. `~/.dex/global/*.{css,js}`
2. `~/.dex/example.com/*.{css,js}`
3. `~/.dex/example.com/*/*.{css,js}`

Files are bunched into one file per file type and served over `https`.

## Talk to me.
Got a problem or a suggestion? Here’s how to get ahold of me, in preferred order:

1. [Start an issue][issues].
2. Bug me on Twitter: [@meyer][]
3. Send me an email maybe: [mikemeyer@gmail.com][]

Here’s how to get ahold of me, in order of expediency:

1. [Start an issue][issues].
2. Bug me on Twitter: [@meyer][]
3. Send me an email maybe: [mikemeyer@gmail.com][]

[crx]: https://chrome.google.com/webstore/detail/dex/djkimknbcjbgnocjbbmliklifoflmfah
[safariextz]: https://github.com/meyer/dex/raw/master/extensions/dex-1.0.1.safariextz
[dexurl]: https://localhost:3131
[@meyer]: http://twitter.com/meyer
[mikemeyer@gmail.com]: mailto:mikemeyer@gmail.com
[issues]: https://github.com/meyer/dex/issues