# Meet Dex.

Quite simply, Dex is tool that allows you to load custom JS
and CSS on a per-site basis.

It’s a two-part system—a tiny li’l webrick server that runs on port
3131 and chucks JS and CSS files from `~/.dex`, and a browser extension that
loads those files (and jQuery) into Your Browser of Choice (assuming that you
chose Chrome or Safari).

## How do I get it?

A fair question, but not one we’ll cover today. If you’d like to install Dex,
though, here’s the deal. Three steps:

1. Clone the `dex` repository to somewhere sensible and install the daemon.

		git clone --recursive https://github.com/meyer/dex.git
		cd dex
		rake

	That’ll install the `dex` server to `/usr/local/bin` and set it to
	automatically start when your computer boots up.

2. Install the browser extension in Your Cool Browser.
	* **Safari**: [Download the Safari extension][safariextz] and double-click
		it to install.
	* **Chrome**: Install the extension at the [official extension page][crx].

3. Go to [https://localhost:3131][dexurl]. Your browser will complain about the
	self-signed SSL certificate. Mark the certificate as “trusted”. There’s an
	“Always Trust” option in there somewhere. Check the box.

## What now?

Dex should be up and running all smooth-like. If you want to modify or
[enhance][] a website, dump JS and CSS files in a URL-named subfolder in
`~/.dex/`. Files are loaded alphabetically, so if you’ve got
one file that relies on another, prefix the filename with an underscore or
something. Or call it something like “aaaa load first.js” Nokia style. Whatever.

If you’re unsure how everything’s loading, you can go to
`localhost:3131/website-url.com.js` or `localhost:3131/website-url.com.css` to
see the file that the extension is loading.

One more thing! Dex looks in `~/.dex/` first before searching the site subfolder
(`~/.dex/website-url.com/`). If you’ve got something that needs to run on every
website or utilities that you want to share between sites, put the corresponsing
files directly in `~/.dex/`.

## Talk to me.
Got a problem or a suggestion?

* Bug me on Twitter: [@meyer][]
* Send me an email maybe: [github.com+dex@meyer.fm][]
* [Start an issue][issues].

[crx]: https://chrome.google.com/webstore/detail/dex/djkimknbcjbgnocjbbmliklifoflmfah
[safariextz]: https://github.com/meyer/dex/raw/master/extensions/dex-1.0.1.safariextz
[dexurl]: https://localhost:3131
[enhance]: http://youtu.be/KiqkclCJsZs
[@meyer]: http://twitter.com/meyer
[github.com+dex@meyer.fm]: mailto:github.com+dex@meyer.fm
[issues]: https://github.com/meyer/dex/issues