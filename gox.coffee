
STEP = process.env.STEP or 15

Gox = require 'goxstream'
JSONStream = require 'json-stream'
Boxcar = require 'boxcar'
log = require 'npmlog'
express = require 'express'

jsonstream = new JSONStream()
gox = null

boxcar = new Boxcar.Provider process.env.BOXCAR_KEY, process.env.BOXCAR_SECRET

port = process.env.PORT or 5000
targetvalue = null
lastvalue = null
reconnectTimer = null

app = express()

app.get '/', (req, res) ->
	res.send "$#{lastvalue}"

app.listen port, () ->
	log.info 'http', "Listening on port #{port}."

notify = (message) ->
	boxcar.broadcast message
	log.info 'notify', message

# goxstream library do not seem to handle reconnects properly,
# we're going to assume that if no data is received for 2 minutes, the
# connection is broken.
resetTimer = () ->
	clearTimeout reconnectTimer if reconnectTimer?
	reconnectTimer = setTimeout reconnect, 2*60*1000

reconnect = () ->
	log.info 'reconnect', 'stream ended, reconnecting stream'

	delete jsonstream if jsonstream?
	delete gox if gox?

	jsonstream = new JSONStream()
	jsonstream.on 'data', processData

	gox = Gox.createStream()
	gox.pipe jsonstream
	resetTimer()

processData = (data) ->
	if not data?.ticker?.last?.value?
		log.warn 'invalid', 'invalid data received', data
		return

	btcvalue = Math.round(parseFloat(data.ticker.last.value))
	lastvalue = btcvalue

	resetTimer()

	log.info 'ticker', "$#{btcvalue}", "([$#{targetvalue - STEP},$#{targetvalue + STEP}])"

	if not targetvalue?
		targetvalue = btcvalue
		return

	if btcvalue > targetvalue + STEP
		notify "bitcoin rising => $#{btcvalue}"
		targetvalue += STEP

	if btcvalue < targetvalue - STEP
		notify "bitcoin falling => $#{btcvalue}"
		targetvalue -= STEP

reconnect()




