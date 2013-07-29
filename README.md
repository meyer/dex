# Meet Dex.

Quite simply, Dex is tool that allows you to load custom JS
and CSS on a per-site basis.

It’s a two-part system—a [tiny li’l webrick server][server] that runs on port
3131 and chucks JS and CSS files from `~/.dex`, and a browser extension that
loads those files (and jQuery) into Your Browser of Choice (assuming that you
chose Chrome or Safari).

## How do I get it?

A fair question, but not one we’ll cover today. If you’d like to install Dex,
though, here’s the deal. Three steps:

1. Install the `dex` daemon.

		git clone https://github.com/meyer/dex.git
		cd dex
		git submodule init
		git submodule update
		rake

	That’ll install the `dex` server to `/usr/local/bin` and set it to
	automatically start when your computer boots up.

2. [Install the browser extension][extension] in Your Cool Browser.
	For Safari, things are pretty simple. Double-click on the  `safariextz`
	file. Chrome extension installation is a bit more obscure. Go to
	[chrome://extensions][chroooome] and drag the `crx` file to
	the extension window.

3. Go to [https://localhost:3131][dexurl]. Your browser will complain about the
	self-signed SSL certificate. Mark the certificate as “trusted”. There’s an
	“Always Trust” option in there somewhere. Check the box.

## What now?

Dex should be up and running all smooth-like. If you want to modify or
[enhance][] a website (let’s say… `website-url.com`), dump a javascript and CSS
in `~/.dex/website-url.com/`. Files are loaded alphabetically, so if you’ve got
one file that relies on another, prefix the filename with an underscore or
something. Or call it something like “aaaa load first.js” Nokia style. Whatever.
If you’re unsure how everything’s loading, you can go to
`localhost:3131/website-url.com.css` or `localhost:3131/website-url.com.css` to
see the file that the extension is loading.

One more thing! Dex looks in `~/.dex/` first before searching the site folder
(`~/.dex/website-url.com/`). If you’ve got something that needs to run on every
website or utilities that you want to share between sites, put the corresponsing
files directly in `~/.dex/`.

## Talk to me.
Got a problem or a suggestion?

* Bug me on Twitter: [@meyer][]
* Send me an email maybe: [github.com+dex@meyer.fm][]
* Start an issue: [https://github.com/meyer/dex/issues]

[server]: /bin/dexd.rb
[extension]: /bin
[chroooome]: chrome://extensions
[dexurl]: https://localhost:3131
[enhance]: http://youtu.be/KiqkclCJsZs
[@meyer]: http://twitter.com/meyer
[github.com+dex@meyer.fm]: mailto:github.com+dex@meyer.fm