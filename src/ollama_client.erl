-module(ollama_client).
-export([chat/2, generate/2,list_models/0]).

-define(OLLAMA_URL, "http://localhost:11434").

chat(Model, Messages) ->
    Body = jsx:encode(#{
        <<"model">> => Model,
        <<"messages">> => Messages,
        <<"stream">> => false
    }),
    request(post, "/api/chat", Body).

generate(Model, Prompt) ->
    Body = jsx:encode(#{
        <<"model">> => Model,
        <<"prompt">> => Prompt,
        <<"stream">> => false
    }),
    request(post, "/api/generate", Body).

request(post, Path, Body) ->
    URL = ?OLLAMA_URL ++ Path,
    Headers = [],
    ContentType = "application/json",
    case httpc:request(post, {URL, Headers, ContentType, Body}, [], []) of
        {ok, {{_, 200, _}, _, ResponseBody}} ->
            {ok, jsx:decode(list_to_binary(ResponseBody), [return_maps])};
        {ok, {{_, Status, _}, _, ResponseBody}} ->
            {error, {Status, ResponseBody}};
        {error, Reason} ->
            {error, Reason}
    end.


list_models() ->
    case httpc:request(get, {?OLLAMA_URL ++ "/api/tags", []}, [], []) of
        {ok, {{_, 200, _}, _, ResponseBody}} ->
            {ok, Response} = {ok, jsx:decode(list_to_binary(ResponseBody), [return_maps])},
            Models = maps:get(<<"models">>, Response),
            {ok, Models};
        {error, Reason} ->
            {error, Reason}
    end.