-- https://github.com/wg/wrk
wrk.method = "POST"
wrk.body   = "select count(*) from tb3;"
wrk.headers["Content-Type"] = "text/plain;charset=UTF-8"