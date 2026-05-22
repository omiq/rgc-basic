10 REM dict_claude_request: build an Anthropic API request body via MAP,
20 REM then POST it. Showcases the integration of all three landed
30 REM proposals: JSON write primitives (Phase 2 JSON work), HTTP
40 REM headers (Phase 3 HTTP work), and DICT (this proposal).
50 REM
60 REM Reads the API key from the ANTHROPIC_API_KEY env var. If unset,
70 REM the example still demonstrates request construction; it just
80 REM skips the actual POST.
90 REM
100 KEY$ = ENV$("ANTHROPIC_API_KEY")
110 PRINT "Building request body via MAP..."
120 REQ = DICTNEW()
130 DICTSET REQ, "model", "claude-haiku-4-5"
140 DICTSET REQ, "max_tokens", 200
150 DICTSET REQ, "messages[0].role", "user"
160 DICTSET REQ, "messages[0].content", "Summarise the role of dictionaries in dynamic languages in one sentence."
170 PRINT
180 PRINT "Request body:"
190 PRINT JSON$(REQ)
200 PRINT
210 IF KEY$ = "" THEN PRINT "ANTHROPIC_API_KEY not set; skipping POST." : DICTFREE REQ : END
220 REM Build headers via MAP, then serialise once. Same MAP, smaller
230 REM tree — and we can hand the JSON string straight to HTTP$.
240 H = DICTNEW()
250 DICTSET H, "x-api-key", KEY$
260 DICTSET H, "anthropic-version", "2023-06-01"
270 DICTSET H, "content-type", "application/json"
280 PRINT "Sending POST..."
290 BODY$ = JSON$(REQ)
300 HEAD$ = JSON$(H)
310 R$ = HTTP$("https://api.anthropic.com/v1/messages", "POST", BODY$, HEAD$)
320 PRINT "HTTP status: "; HTTPSTATUS()
330 IF HTTPSTATUS() <> 200 THEN PRINT R$ : DICTFREE REQ : DICTFREE H : END
340 REM Parse the response into a map so we can pluck fields by path.
350 RESP = DICTLOAD(R$)
360 PRINT
370 PRINT "Reply text:"
380 PRINT DICTGET$(RESP, "content[0].text")
390 PRINT
400 PRINT "Tokens used: in="; DICTGETN(RESP, "usage.input_tokens"); " out="; DICTGETN(RESP, "usage.output_tokens")
410 DICTFREE REQ
420 DICTFREE H
430 DICTFREE RESP
