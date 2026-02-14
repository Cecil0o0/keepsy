-- https://github.com/wg/wrk
wrk.method = "POST"
wrk.body   = "insert into tb3 values(\"wrk11\",100,\"RAM User\",\"xxx\",\"1107550004253538\",\"1107550004253538\");"
wrk.headers["Content-Type"] = "text/plain;charset=UTF-8"