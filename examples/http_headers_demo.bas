10 REM http_headers_demo: POST a JSON body with custom headers.
20 REM Hits httpbin.org/post which echoes the request back so we can
30 REM verify both the body and headers landed.
40 REM
50 REM Requires:
60 REM   native  curl on PATH
70 REM   wasm    CORS-friendly endpoint (httpbin.org is fine)
80 REM
90 REM Build a JSON body via JSONNEW$ / JSONPUT$ — no manual escaping.
100 B$ = JSONNEW$("object")
110 B$ = JSONPUT$(B$, "user", "alice")
120 B$ = JSONPUT$(B$, "stars", 5)
130 B$ = JSONPUT$(B$, "tags[0]", "demo")
140 B$ = JSONPUT$(B$, "tags[1]", "rgc-basic")
150 PRINT "Sending body: " + B$
160 REM
170 REM Build headers as a JSON object — keys become HTTP header names.
180 H$ = JSONNEW$("object")
190 H$ = JSONPUT$(H$, "Content-Type", "application/json")
200 H$ = JSONPUT$(H$, "X-RGC-Demo", "phase3")
210 REM
220 R$ = HTTP$("https://httpbin.org/post", "POST", B$, H$)
230 PRINT "Status: " + STR$(HTTPSTATUS())
240 IF HTTPSTATUS() <> 200 THEN PRINT "Request failed." : END
250 PRINT
260 PRINT "Echoed user: " + JSON$(R$, "json.user")
270 PRINT "Echoed stars: " + JSON$(R$, "json.stars")
280 PRINT "Echoed tags[0]: " + JSON$(R$, "json.tags[0]")
290 PRINT "Echoed X-Rgc-Demo header: " + JSON$(R$, "headers.X-Rgc-Demo")
300 PRINT "Echoed Content-Type: " + JSON$(R$, "headers.Content-Type")
