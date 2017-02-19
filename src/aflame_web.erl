-module(aflame_web).
-define(HTTP_CHUNK_SIZE, 1048576).
-define(MAX_TRACE_SIZE, 33554432).

-export([
    start/0,
    init/3,
    handle/2,
    terminate/3
]).

-compile([{parse_transform, lager_transform}]).

start() ->
    {ok, ServerInfo} = application:get_env(aflame, server),
    Port = proplists:get_value(http_port, ServerInfo),
    Dispatch = cowboy_router:compile([
        {'_', [
            {'_', ?MODULE, []}
        ]}
    ]),
    {ok, _} = cowboy:start_http(
        http, 10, [{port, Port}], [{env, [{dispatch, Dispatch}]}]
    ),
    ok.

max_trace_size() ->
    {ok, ServerInfo} = application:get_env(aflame, server),
    MaxSize = proplists:get_value(max_upload_size, ServerInfo),
    MaxSize.

init(_Transport, Req, [])->
    {ok, Req, undefined}.

handle(Req, State) ->
    {Path, Req} = cowboy_req:path(Req),
    Args = string:tokens(binary_to_list(Path), "/"),
    try handle_rest(Req, Args) of
        {ok, Req2} -> {ok, Req2, State}
    catch
        throw:{Code, ResponseText} ->
            {ok, Req2} = write_reply(Req, ResponseText, Code),
            {ok, Req2, State};
        throw:Throw ->
            lager:error("Caught throw:~p~n", [Throw]),
            {ok, Req2} = internal_error(Req),
            {ok, Req2, State};
        error:Error ->
            lager:error("Caught ~p error:~p~n", [Error, erlang:get_stacktrace()]),
            {ok, Req2} = internal_error(Req),
            {ok, Req2, State}
    end.

write_reply(Req, Data) ->
    write_reply(Req, Data, 200).
write_reply(Req, Data, Code) ->
    cowboy_req:reply(Code, [
        {<<"content-type">>, <<"text/plain; charset=utf-8">>}
    ], Data, Req).

internal_error(Req) ->
    write_reply(Req, "Internal error", 500).

handle_rest(Req, ["upload_trace"]) ->
    upload_trace(Req);
handle_rest(Req, Path) ->
    lager:info("Requested unknown url: ~p~n", [Path]),
    write_reply(Req, "Unknown URL", 404).

upload_trace(Req) ->
    {ok, OutName, OutFile} = aflame_fs:get_temp_file(),
    case stream_trace_to_file(Req, OutFile) of
        {ok, Req1} ->
            file:close(OutFile),
            {ok, Md5} = aflame_fs:rename_to_md5(OutName),
            lager:info("Wrote new trace to ~p~n", [Md5]),
            write_reply(Req1, "OK");
        {error, trace_too_large} ->
            write_reply(
              Req,
              io_lib:format("Tracefile too large - max size ~p~n", [max_trace_size()])
             )
    end.

stream_trace_to_file(Req, OutFile) ->
    stream_trace_to_file(Req, OutFile, 0).
stream_trace_to_file(_Req, _OutFile, Bytes) when Bytes > ?MAX_TRACE_SIZE ->
    {error, trace_too_large};
stream_trace_to_file(Req, OutFile, Bytes) ->
    case cowboy_req:body(Req) of
        {ok, Data, Req1} ->
            file:write(OutFile, Data),
            {ok, Req1};
        {more, Data, Req1} ->
            file:write(OutFile, Data),
            stream_trace_to_file(Req1, OutFile, Bytes + byte_size(Data))
    end.

terminate(_Reason, _Req, _State) ->
    ok.