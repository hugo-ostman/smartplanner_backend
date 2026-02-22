-module(google_public_calendar).
-export([get_events/0, get_events/1, get_events/2]).



%% Hämta händelser från publik kalender 
get_events() ->
    get_events("sv.swedish#holiday@group.v.calendar.google.com").

get_events(CalendarId) ->
    get_events(CalendarId, #{}).

get_events(CalendarId, Opts) ->
    %% Du behöver en API-nyckel från Google Cloud Console
    ApiKey = "AIzaSyCm-1NMSJmmwqZ8dY35dCplQ0FfwiFdmUY",
    
    BaseUrl = "https://www.googleapis.com/calendar/v3/calendars/" ++ 
              uri_string:quote(CalendarId) ++ "/events",
    
    %% Bygg query parameters
    QueryParams = [
        {"key", ApiKey},
        {"maxResults", integer_to_list(maps:get(max_results, Opts, 10))},
        {"singleEvents", "true"},
        {"orderBy", "startTime"}
    ],
    
    %% Lägg till tidsgränser om angivna
    QueryParamsWithTime = case maps:get(time_min, Opts, undefined) of
        undefined -> QueryParams;
        TimeMin -> [{"timeMin", TimeMin} | QueryParams]
    end,
    
    Url = BaseUrl ++ "?" ++ build_query_string(QueryParamsWithTime),
    
    %% Gör förfrågan
    case httpc:request(get, {Url, []}, [], []) of
        {ok, {{_, 200, _}, _, ResponseBody}} ->
            %% Parsa JSON
            Events = jsx:decode(list_to_binary(ResponseBody), [return_maps]),
            {ok, Events};
        {ok, {{_, StatusCode, _}, _, ErrorBody}} ->
            {error, {StatusCode, ErrorBody}};
        Error ->
            {error, Error}
    end.

%% Hjälpfunktion
build_query_string(Params) ->
    string:join([
        Key ++ "=" ++ uri_string:quote(Value)
        || {Key, Value} <- Params
    ], "&").