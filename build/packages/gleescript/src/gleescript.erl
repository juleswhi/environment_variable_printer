-module(gleescript).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([run/0, main/0]).
-export_type([config/0, erlang_option/0, never/0]).

-type config() :: {config, binary()}.

-type erlang_option() :: shebang |
    {comment, gleam@erlang@charlist:charlist()} |
    {emu_args, gleam@erlang@charlist:charlist()} |
    {archive,
        list({gleam@erlang@charlist:charlist(), bitstring()}),
        list(never())}.

-type never() :: any().

-spec snag_inspect_error({ok, IGC} | {error, any()}) -> {ok, IGC} |
    {error, snag:snag()}.
snag_inspect_error(Result) ->
    case Result of
        {ok, Value} ->
            {ok, Value};

        {error, Error} ->
            snag:error(gleam@string:inspect(Error))
    end.

-spec locate_beam_files() -> {ok, list(binary())} | {error, snag:snag()}.
locate_beam_files() ->
    gleam@result:'try'(
        begin
            _pipe = simplifile:get_files(<<"build/dev/erlang"/utf8>>),
            _pipe@1 = snag_inspect_error(_pipe),
            snag:context(_pipe@1, <<"Failed to read build directory"/utf8>>)
        end,
        fun(Files) -> _pipe@2 = Files,
            _pipe@3 = gleam@list:filter(
                _pipe@2,
                fun(F) ->
                    not gleam_stdlib:contains_string(F, <<"@@"/utf8>>) andalso (gleam@string:ends_with(
                        F,
                        <<".beam"/utf8>>
                    )
                    orelse gleam@string:ends_with(F, <<".app"/utf8>>))
                end
            ),
            {ok, _pipe@3} end
    ).

-spec load_config() -> {ok, config()} | {error, snag:snag()}.
load_config() ->
    gleam@result:'try'(
        begin
            _pipe = simplifile:read(<<"gleam.toml"/utf8>>),
            _pipe@1 = snag_inspect_error(_pipe),
            snag:context(_pipe@1, <<"Failed to read gleam.toml"/utf8>>)
        end,
        fun(Text) ->
            gleam@result:'try'(
                begin
                    _pipe@2 = tom:parse(Text),
                    _pipe@3 = snag_inspect_error(_pipe@2),
                    snag:context(_pipe@3, <<"Failed to parse gleam.toml"/utf8>>)
                end,
                fun(Config) ->
                    gleam@result:'try'(
                        begin
                            _pipe@4 = tom:get_string(Config, [<<"name"/utf8>>]),
                            _pipe@5 = snag_inspect_error(_pipe@4),
                            snag:context(
                                _pipe@5,
                                <<"Failed to get package name from gleam.toml"/utf8>>
                            )
                        end,
                        fun(Package_name) -> {ok, {config, Package_name}} end
                    )
                end
            )
        end
    ).

-spec run() -> {ok, nil} | {error, snag:snag()}.
run() ->
    gleam@result:'try'(
        begin
            _pipe = load_config(),
            snag:context(_pipe, <<"Failed to load configuration"/utf8>>)
        end,
        fun(Config) ->
            gleam@result:'try'(
                begin
                    _pipe@1 = locate_beam_files(),
                    snag:context(
                        _pipe@1,
                        <<"Failed to scan packages in build directory"/utf8>>
                    )
                end,
                fun(Files) ->
                    Emu_args = <<"-escript main gleescript_main_shim -env GLEESCRIPT_MAIN "/utf8,
                        (erlang:element(2, Config))/binary>>,
                    gleam@result:'try'(
                        gleam@list:try_map(
                            Files,
                            fun(F) ->
                                Name = unicode:characters_to_list(
                                    filepath:base_name(F)
                                ),
                                gleam@result:map(
                                    begin
                                        _pipe@2 = simplifile:read_bits(F),
                                        _pipe@3 = snag_inspect_error(_pipe@2),
                                        snag:context(
                                            _pipe@3,
                                            <<"Failed to read "/utf8, F/binary>>
                                        )
                                    end,
                                    fun(Content) -> {Name, Content} end
                                )
                            end
                        ),
                        fun(Files@1) ->
                            Result = escript:create(
                                unicode:characters_to_list(
                                    erlang:element(2, Config)
                                ),
                                [shebang,
                                    {comment,
                                        unicode:characters_to_list(<<""/utf8>>)},
                                    {emu_args,
                                        unicode:characters_to_list(Emu_args)},
                                    {archive, Files@1, []}]
                            ),
                            _assert_subject = (gleam@dynamic:result(
                                fun(Field@0) -> {ok, Field@0} end,
                                fun(Field@0) -> {ok, Field@0} end
                            ))(Result),
                            {ok, Result@1} = case _assert_subject of
                                {ok, _} -> _assert_subject;
                                _assert_fail ->
                                    erlang:error(#{gleam_error => let_assert,
                                                message => <<"Assertion pattern match failed"/utf8>>,
                                                value => _assert_fail,
                                                module => <<"gleescript"/utf8>>,
                                                function => <<"run"/utf8>>,
                                                line => 66})
                            end,
                            gleam@result:'try'(
                                begin
                                    _pipe@4 = Result@1,
                                    _pipe@5 = snag_inspect_error(_pipe@4),
                                    snag:context(
                                        _pipe@5,
                                        <<"Failed to build escript"/utf8>>
                                    )
                                end,
                                fun(_) ->
                                    gleam@io:println(
                                        <<"  \x{001b}[35mGenerated\x{001b}[0m ./"/utf8,
                                            (erlang:element(2, Config))/binary>>
                                    ),
                                    {ok, nil}
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-spec main() -> nil.
main() ->
    case run() of
        {ok, _} ->
            nil;

        {error, Error} ->
            gleam@io:println_error(snag:pretty_print(Error)),
            init:stop(1)
    end.
