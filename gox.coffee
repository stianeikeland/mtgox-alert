
STEP = process.env.STEP or 15

Gox = require 'goxstream'
JSONStream = require 'json-stream'
Boxcar = require 'boxcar'
log = require 'npmlog'
express = require 'express'

jsonstream = new JSONStream()

boxcar = new Boxcar.Provider process.env.BOXCAR_KEY, process.env.BOXCAR_SECRET

port = process.env.PORT or 5000
targetvalue = null
lastvalue = null

app = express()

app.get '/', (req, res) ->
	res.send "$#{lastvalue}"

app.listen port, () ->
	log.info 'http', "Listening on port #{port}."

startStream = (jsonstream) ->
	gox = Gox.createStream()
	gox.pipe jsonstream
	gox

notify = (message) ->
	boxcar.broadcast message
	log.info 'notify', message

processData = (data) ->
	if not data?.ticker?.last?.value?
		log.warn 'invalid', 'invalid data received', data
		return

	btcvalue = Math.round(parseFloat(data.ticker.last.value))
	lastvalue = btcvalue

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

jsonstream.on 'data', processData

gox = startStream jsonstream

gox.on 'end', () ->
	log.info 'reconnect', 'stream ended, reconnecting stream'
	gox = startStream jsonstream






