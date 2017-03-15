#!/usr/bin/env escript
%% -*- erlang -*-
%%! -smp enable -name pingy@127.0.0.1 -cookie antidote
-mode(compile).



%% This should be called like (e.g.): $join_cluster_script.erl 'antidote1@1.2.3.4' 'antidote2@5.6.7.8'
main([NodeToPing]) ->
%%    io:format("~n pinging ~p~n",[NodeToPing]),
    erlang:set_cookie(node(), antidote),
    try
        Result=net_adm:ping(list_to_atom(NodeToPing)),
            io:format("~p", [Result]),
            Result
    catch
        _:_ ->
            usage()
    end.

usage() ->
    io:format("This should be called like (e.g.): ping.erl 'antidote1@1.2.3.4'~n"),
    pang.