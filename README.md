# Meet Dex.

**Dex** is tool that allows you (yes, you!) to modify any website with CSS and JavaScript.

It’s a two-part system:

1. A tiny little **daemon** that serves blobs of CSS and JS.
2. A **browser extension** for Chrome that loads those blobs into your browser.

## Modules: The core of Dex

Every time you visit a URL, the Dex browser extension loads CSS and JavaScript files for that specific domain. These files are built based on **modules** that you have enabled in the Dex extension popover.

What is a **module**? It’s a sensibly-named folder with some CSS and/or JS files that, when included on a webpage, accomplish a single task.

Modules live inside a folder called `.dex` in your home folder. I’m going to assume you’re the technical type and we’ll just call that `~/.dex/` from now on.

## Writing your first module

1. Think about what you want this module to do, then create a folder with a succinct name based on what the module does. Want to make a website’s background red? A folder called `Change body background to red` would do the trick.

2. Put CSS and JS files in the folder you just created. Congrats, you just created a module! :tada:

3. Think about what the scope of this module should be, then place it in one of three subfolders inside `~/.dex/`:

  * :computer: **Site-specific module**: If you want to modify *one particular site*, you’ll want to place the module in a *site-specific folder*. Site-specific folders are URL-named folders (`github.com`, `google.com`, etc.). Enabled site-specific modules are only loaded for the *exact matching URL*. Subdomains of URLs are treated as separate URLs and can be configured independently of the parent URL, but they have access to all the parent URL’s modules.

  * :earth_africa: **Global module**: If you want to modify *every site you visit*, you’ll want to put the module inside a folder called `global`. Enabled global modules are loaded for *every website* you visit, so don’t go too crazy.

  * :hammer: **Utility module**: If you want a module to be available to any site, but you want it affect sites on an individual basis, put the module inside a folder called `utilities`. Utility modules show up as regular site-specific modules in the Dex popover, but enabling a utility module will only enable it for the specific domain that you’ve browsed to.

4. Visit the URL you want to modify, open the Dex popover menu, and click the switch next to whatever modules you want to enable. *Whammy.* There it is.

# Installation

* **Dex daemon:** `dexd` is available as a Homebrew tap. Run `brew install --HEAD meyer/dex/dexd`. Be sure to read the caveats. TLDR:

  * Make sure either a folder or a symlink to a folder exists at `~/.dex/`. I’ve symlinked `~/.dex/` to the [dexfiles folder][shameless self-promotion] in my Dropbox. Works quite nicely.

  * If you want `dexd` to run on boot, run `brew services start meyer/dex/dexd` to install the launchagent.

* **Browser extension:** You can find the Dex extension on the [Chrome Web Store][dex-ext].

# Good Things 2 Know

## File Load Order

Dex loads files in the following order:

1. `global/*.js`
2. `global/*/*.{css,js}`
3. `example.com/*.js`
4. `example.com/*/*.{css,js}`


## Debugging

Two JS files and two CSS files are loaded for each domain. For `github.com`, the following files would be loaded:

* `https://localhost:3131/global.js`
* `https://localhost:3131/global.css`
* `https://localhost:3131/github.com.js`
* `https://localhost:3131/github.com.css`

If something isn’t showing up, check one of those files to see if the JS/CSS is in there.

# Talk to me.
Got a problem or a suggestion?

1. [Start an issue][issues].
2. Send me an email: [email][]
3. Bug me on Twitter: [@meyer][]

[dex-ext]: https://chrome.google.com/webstore/detail/dex/eclmkmapdnpgbaidmeoadgcfaaapahhn
[@meyer]: http://twitter.com/meyer
[email]: mailto:github.com+dex@meyer.fm
[issues]: https://github.com/meyer/dex-ext/issues
[shameless self-promotion]: https://github.com/meyer/dexfiles
