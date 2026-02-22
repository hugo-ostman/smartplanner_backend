-module(smartplanner_db).


-export([
    init/0,
    stop/0,
    add_user/3,
    get_user/1,
    update_user/3,
    delete_user/1,
    list_users/0
]).

-export([save_token/2, get_user_id_by_token/1]).


-include("user.hrl").
-include("event.hrl").


%%%===================================================================
%%% INIT
%%%===================================================================

init() ->
    mnesia:stop(),
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia:create_table(user, [
        {attributes, record_info(fields, user)},
        {disc_copies, [node()]},
        {index, [#user.mail]}

    ]),
    mnesia:create_table(event, [
    {attributes, record_info(fields, event)},
    {disc_copies, [node()]}
     ]),
    mnesia:create_table(token, [
    {attributes, [token, user_id]},
    {disc_copies, [node()]}
   ]).

stop() ->
    mnesia:stop().

%%%===================================================================
%%% CRUD
%%%===================================================================

add_user(Mail, Password, Name) ->
    F = fun() ->
        case mnesia:index_read(user, Mail, #user.mail) of
            [] ->
                Id = erlang:unique_integer([monotonic, positive]),
              
                PasswordHash = password:hash(Password),
                mnesia:write(#user{id=Id, mail = Mail, password = PasswordHash,  name = Name}),
                ok;
            _ ->
                {error, user_exists}
        end
    end,
 {atomic, Result} = mnesia:transaction(F),
 Result.

get_user(Mail) ->
    F = fun() ->
        case mnesia:index_read(user, Mail, #user.mail) of
            [User] -> {ok, User};
            [] -> {error, not_found}
        end
    end,
 {atomic, Result} = mnesia:transaction(F),
 Result.

update_user(Mail, Password, Name) ->
    F = fun() ->
        case mnesia:index_read(user, Mail, #user.mail) of
            [#user{}=User] ->
                mnesia:write(User#user{mail = Mail, password = Password, name = Name}),
                ok;
            [] ->
                {error, not_found}
        end
    end,
 {atomic, Result} = mnesia:transaction(F),
 Result.

delete_user(Mail) ->
    F = fun() ->
        mnesia:index_delete(user, Mail, #user.mail)
    end,
 {atomic, Result} = mnesia:transaction(F),
 Result.

list_users() ->
    F = fun() ->
        mnesia:match_object(#user{mail = '_', password = '_', name = '_'})
    end,
    mnesia:transaction(F).


%%%===================================================================
%%% Token
%%%===================================================================


save_token(Token, UserId) ->
    F = fun() -> mnesia:write({token, Token, UserId}) end,
    mnesia:transaction(F).

get_user_id_by_token(Token) ->
    F = fun() ->
        case mnesia:read(token, Token) of
            [{token, _, UserId}] -> {ok, UserId};
            [] -> {error, not_found}
        end
    end,
    {atomic, Result} = mnesia:transaction(F),
    Result.