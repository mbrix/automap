%% Idempotent dynamic module to map constants into a static namespace

-module(automap).
-author('mbranton@gmail.com').

-export([init/2,
         map/1]).

init(DynamicModule, Map) -> do_init(code:is_loaded(DynamicModule), DynamicModule, Map).

do_init(true, _, _) -> error;
do_init(false, DynamicModule, Map) ->
    Module = erl_syntax:attribute(erl_syntax:atom(module),[erl_syntax:atom(DynamicModule)]),
    ModForm =  erl_syntax:revert(Module),

    Export = erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list([erl_syntax:arity_qualifier(erl_syntax:atom(get_map),
                                                                               erl_syntax:integer(0))])]),
    ExportForm = erl_syntax:revert(Export),

    Clause1 =  erl_syntax:clause([],[],[ast_syntax_body(Map)]),

    Function =  erl_syntax:function(erl_syntax:atom(get_map),[Clause1]),
    FunctionForm = erl_syntax:revert(Function),

    {ok, Mod, Bin1} = compile:forms([ModForm,ExportForm, FunctionForm]),
    code:load_binary(Mod, [], Bin1),
    ok.


ast_syntax_body(NetMap) ->
    erl_syntax:map_expr( maps:fold(fun(K, V, Acc) when is_integer(V) ->
                                           [erl_syntax:map_field_assoc(erl_syntax:atom(K),
                                                                       erl_syntax:integer(V))|Acc];
                                      (K, V, Acc) when is_binary(V) ->
                                           [erl_syntax:map_field_assoc(erl_syntax:atom(K),
                                                                       erl_syntax:binary(lists:map(fun(I) ->
                                                                                                           erl_syntax:binary_field(erl_syntax:integer(I))
                                                                                                   end, binary_to_list(V))))|Acc];
                                      (K, V, Acc) when is_atom(V) ->
                                           [erl_syntax:map_field_assoc(erl_syntax:atom(K), erl_syntax:atom(V))|Acc];
                                      (K, V, Acc) when is_list(V) ->
                                           [erl_syntax:map_field_assoc(erl_syntax:atom(K), erl_syntax:char(V))|Acc]
                                   end, [], NetMap)).

map(DynamicModule) -> get_map(code:is_loaded(DynamicModule), DynamicModule).

get_map(false, _) -> throw(map_not_initialized);
get_map(_, DynamicModule)  -> DynamicModule:get_map().

