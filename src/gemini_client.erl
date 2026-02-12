-module(gemini_client).
-export([test/0, list_models/0]).


-define(GEMINI_API_KEY, "AIzaSyCTwKufRG0Ww4v11MCYw9QrOu8SLp7OrJQ").

list_models() ->
    URL = "https://generativelanguage.googleapis.com/v1beta/models?key=" ++ ?GEMINI_API_KEY,
    
    case httpc:request(get, {URL, []}, [{timeout, 30000}], []) of
        {ok, {{_, 200, _}, _, ResponseBody}} ->
              io:format("Response Body: ~s~n", [ResponseBody]),
            Decoded = jsx:decode(list_to_binary(ResponseBody), [return_maps]),
            Models = maps:get(<<"models">>, Decoded, []),
            io:format("Tillgängliga modeller:~n"),
            lists:foreach(fun(Model) ->
                Name = maps:get(<<"name">>, Model),
                SupportedMethods = maps:get(<<"supportedGenerationMethods">>, Model, []),
                io:format("  - ~s: ~p~n", [Name, SupportedMethods])
            end, Models),
            {ok, Models};
        {ok, {{_, StatusCode, _}, _, ErrorBody}} ->
            io:format("Fel ~p: ~s~n", [StatusCode, ErrorBody]),
            {error, StatusCode};
        {error, Reason} ->
            io:format("HTTP-fel: ~p~n", [Reason]),
            {error, Reason}
    end.

%% Testa att anropa Gemini
test() ->
    ApiKey = ?GEMINI_API_KEY,
    
    Body = jsx:encode(#{
        <<"contents">> => [
            #{
                <<"parts">> => [
                    #{<<"text">> => <<"Skriv en kort dikt">>}
                ]
            }
        ]
    }),
    
    % Prova olika modellnamn
    ModelName = "gemini-2.5-flash", % Exempelmodell, byt ut mot en som finns i list_models/0
    URL = "https://generativelanguage.googleapis.com/v1beta/models/" ++ ModelName ++ ":generateContent?key=" ++ ApiKey,
    
   


    io:format("Anropar URL: ~s~n", [URL]),
    
    case httpc:request(post,
        {URL, [], "application/json", Body},
        [{timeout, 30000}],
        []) of
        {ok, {{_, 200, _}, _Headers, ResponseBody}} ->
            Decoded = jsx:decode(list_to_binary(ResponseBody), [return_maps]),
            io:format("Svar: ~p~n", [Decoded]),
            {ok, Decoded};
        {ok, {{_, StatusCode, _}, _, ErrorBody}} ->
            io:format("Fel ~p: ~s~n", [StatusCode, ErrorBody]),
            {error, StatusCode};
        {error, Reason} ->
            io:format("HTTP-fel: ~p~n", [Reason]),
            {error, Reason}
    end.


