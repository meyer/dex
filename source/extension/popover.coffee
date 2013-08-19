console.log 'FRICCCKKKKKKK 2'

currentPageURL = 'ERROR'

if window.safari
	currentPageURL = safari.application.activeBrowserWindow.activeTab.url
	# Strip down to hostname
	currentPageURL = currentPageURL.split('//')[1].split('/')[0]
	# Remove www
	currentPageURL = currentPageURL.replace /^www\./, ''
#TODO: Chrome support

dexURL = "https://localhost:3131/#{currentPageURL}.html"
document.write "<iframe src='#{dexURL}'></iframe>"