-module(password).
-export([hash/1, verify/2]).

hash(Password) ->
    Salt = crypto:strong_rand_bytes(16),
    Hash = pbkdf2(Password, Salt, 100000, 32),
    [Salt, Hash].

verify(Password, [Salt, Hash]) ->
    NewHash = pbkdf2(Password, Salt, 100000, 32),
    crypto:hash_equals(Hash, NewHash).

%% PBKDF2 implementation
pbkdf2(Password, Salt, Iterations, DkLen) ->
    pbkdf2_blocks(Password, Salt, Iterations, DkLen, 1, <<>>).

pbkdf2_blocks(_Password, _Salt, _Iter, DkLen, _Block, Acc)
    when byte_size(Acc) >= DkLen ->
    binary:part(Acc, 0, DkLen);
pbkdf2_blocks(Password, Salt, Iter, DkLen, Block, Acc) ->
    BlockData = pbkdf2_f(Password, Salt, Iter, Block),
    pbkdf2_blocks(Password, Salt, Iter, DkLen, Block + 1, <<Acc/binary, BlockData/binary>>).

pbkdf2_f(Password, Salt, Iterations, Block) ->
    BlockInt = <<Block:32/integer>>,
    U1 = hmac(Password, <<Salt/binary, BlockInt/binary>>),
    pbkdf2_iterate(Password, U1, U1, Iterations - 1).

pbkdf2_iterate(_Password, _Prev, Acc, 0) -> Acc;
pbkdf2_iterate(Password, Prev, Acc, Iter) ->
    Next = hmac(Password, Prev),
    pbkdf2_iterate(Password, Next, crypto:exor(Acc, Next), Iter - 1).

hmac(Key, Data) ->
    crypto:mac(hmac, sha256, Key, Data).