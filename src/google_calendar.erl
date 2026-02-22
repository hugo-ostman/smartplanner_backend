-module(google_calendar).
-export([get_events/1, get_access_token/1]).

%% Kräver att du har httpc och ssl startade
start() ->
    application:ensure_all_started(inets),
    application:ensure_all_started(ssl).

%% Hämta access token med OAuth2
get_access_token(RefreshToken) ->
    Url = "https://oauth2.googleapis.com/token",
    ClientId = "DIN_CLIENT_ID",
    ClientSecret = "DIN_CLIENT_SECRET",
    
    Body = "client_id=" ++ ClientId ++ 
           "&client_secret=" ++ ClientSecret ++
           "&refresh_token=" ++ RefreshToken ++
           "&grant_type=refresh_token",
    
    Headers = [{"Content-Type", "application/x-www-form-urlencoded"}],
    
    case httpc:request(post, {Url, Headers, "application/x-www-form-urlencoded", Body}, [], []) of
        {ok, {{_, 200, _}, _, ResponseBody}} ->
            %% Parsa JSON för att få access_token
            {ok, ResponseBody};
        Error ->
            {error, Error}
    end.

%% Hämta kalenderhändelser
get_events(AccessToken) ->
    CalendarId = "primary", %% eller specifik calendar ID
    Url = "https://www.googleapis.com/calendar/v3/calendars/" ++ 
          CalendarId ++ "/events",
    
    Headers = [{"Authorization", "Bearer " ++ AccessToken}],
    
    case httpc:request(get, {Url, Headers}, [], []) of
        {ok, {{_, 200, _}, _, ResponseBody}} ->
            %% Parsa JSON-svaret
            {ok, ResponseBody};
        Error ->
            {error, Error}
    end.